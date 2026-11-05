#include "MD4CParser.hpp"

#include <cstdio>
#include <string>

using Markdown::MarkdownASTNode;
using Markdown::Md4cFlags;
using Markdown::MD4CParser;
using Markdown::NodeType;

namespace {

int failures = 0;
int checks = 0;

const char *typeName(NodeType type) {
  switch (type) {
    case NodeType::Document: return "Document";
    case NodeType::Paragraph: return "P";
    case NodeType::Text: return "Text";
    case NodeType::Link: return "Link";
    case NodeType::Heading: return "H";
    case NodeType::LineBreak: return "BR";
    case NodeType::Strong: return "Strong";
    case NodeType::Emphasis: return "Em";
    case NodeType::UnorderedList: return "UL";
    case NodeType::OrderedList: return "OL";
    case NodeType::ListItem: return "LI";
    case NodeType::Citation: return "Cite";
    case NodeType::Dose: return "Dose";
    default: return "Other";
  }
}

void serialize(const MarkdownASTNode &node, std::string &out) {
  out += typeName(node.type);
  if (node.type == NodeType::Text) {
    out += "\"" + node.content + "\"";
    return;
  }
  if (node.type == NodeType::Citation) {
    out += "[" + node.content + "]";
    return;
  }
  if (node.type == NodeType::Dose) {
    out += "[";
    bool first = true;
    for (const char *key : {"id", "state", "calc", "label"}) {
      auto it = node.attributes.find(key);
      if (it == node.attributes.end()) continue;
      if (!first) out += ",";
      out += std::string(key) + "=" + it->second;
      first = false;
    }
    out += "]";
  }
  if (node.children.empty()) return;
  out += "(";
  for (size_t i = 0; i < node.children.size(); ++i) {
    if (i) out += ",";
    serialize(*node.children[i], out);
  }
  out += ")";
}

std::string parse(const std::string &markdown, bool doseTags = true) {
  MD4CParser parser;
  Md4cFlags flags;
  flags.doseTags = doseTags;
  auto root = parser.parse(markdown, flags);
  std::string out;
  for (size_t i = 0; i < root->children.size(); ++i) {
    if (i) out += " | ";
    serialize(*root->children[i], out);
  }
  return out;
}

void expect(const char *name, const std::string &markdown, const std::string &expected, bool doseTags = true) {
  ++checks;
  std::string actual = parse(markdown, doseTags);
  if (actual != expected) {
    ++failures;
    std::printf("FAIL %s\n  input:    %s\n  expected: %s\n  actual:   %s\n", name, markdown.c_str(), expected.c_str(),
                actual.c_str());
  } else {
    std::printf("ok   %s\n", name);
  }
}

}

int main() {
  expect("dose with every attribute becomes a Dose node",
         "Apixaban <dose id=\"d1\" state=\"green\" calc=\"1\" label=\"Checked against the FDA label\">5 mg twice "
         "daily</dose> is the dose.",
         "P(Text\"Apixaban \",Dose[id=d1,state=green,calc=1,label=Checked against the FDA label](Text\"5 mg twice "
         "daily\"),Text\" is the dose.\")");

  expect("flag off keeps today's behaviour: tag dropped, words kept",
         "Apixaban <dose id=\"d1\" state=\"green\">5 mg twice daily</dose> is the dose.",
         "P(Text\"Apixaban 5 mg twice daily is the dose.\")", false);

  expect("bold inside a dose", "<dose id=\"d1\" state=\"amber\">**250 mg** every 6 hours</dose>",
         "P(Dose[id=d1,state=amber](Strong(Text\"250 mg\"),Text\" every 6 hours\"))");

  expect("dose inside bold", "**<dose id=\"d1\" state=\"green\">10 mg</dose>** twice daily",
         "P(Strong(Dose[id=d1,state=green](Text\"10 mg\")),Text\" twice daily\")");

  expect("a dose left open when its span ends closes with the span",
         "**<dose id=\"d1\" state=\"green\">10 mg** twice daily</dose> after",
         "P(Strong(Dose[id=d1,state=green](Text\"10 mg\")),Text\" twice daily after\")");

  expect("an unclosed dose ends with its paragraph",
         "Give <dose id=\"d1\" state=\"green\">10 mg twice daily\n\nNext paragraph.",
         "P(Text\"Give \",Dose[id=d1,state=green](Text\"10 mg twice daily\")) | P(Text\"Next paragraph.\")");

  expect("a stray closing tag is dropped", "Before </dose> after", "P(Text\"Before  after\")");

  expect("two doses in one paragraph",
         "<dose id=\"a\" state=\"green\">5 mg</dose> or <dose id=\"b\" state=\"amber\">2.5 mg</dose>.",
         "P(Dose[id=a,state=green](Text\"5 mg\"),Text\" or \",Dose[id=b,state=amber](Text\"2.5 mg\"),Text\".\")");

  expect("citations inside and after a dose still become chips",
         "<dose id=\"d1\" state=\"green\">5 mg [[2|FDA|]]</dose> daily [[1|FDA|]]",
         "P(Dose[id=d1,state=green](Text\"5 mg \",Cite[FDA]),Text\" daily \",Cite[FDA])");

  expect("dose in a list item", "- <dose id=\"d1\" state=\"green\">10 mg BID</dose> for 7 days\n- next",
         "UL(LI(Dose[id=d1,state=green](Text\"10 mg BID\"),Text\" for 7 days\"),LI(Text\"next\"))");

  expect("upper case, single quotes and bare values",
         "<DOSE ID='d1' State=amber calc=1>5 mg</DOSE>",
         "P(Dose[id=d1,state=amber,calc=1](Text\"5 mg\"))");

  expect("other tag names that start with dose are not doses", "<doses id=\"x\">5 mg</doses>",
         "P(Text\"5 mg\")");

  expect("the app's final-copy markup",
         "the labeled apixaban dose is <dose id=\"d1\" state=\"green\" calc=\"1\" label=\"checked against the FDA "
         "label, with a dosing calculator\">5 mg orally twice daily</dose>.[[1|DailyMed|]]",
         "P(Text\"the labeled apixaban dose is \",Dose[id=d1,state=green,calc=1,label=checked against the FDA "
         "label, with a dosing calculator](Text\"5 mg orally twice daily\"),Text\".\",Cite[DailyMed])");
  expect("a self-closing dose marks nothing", "A <dose id=\"x\"/> B", "P(Text\"A  B\")");

  expect("a half-written tag at the end stays text (the app strips it while streaming)",
         "Apixaban <dose id=\"d1", "P(Text\"Apixaban <dose id=\"d1\")");

  std::printf("%d checks, %d failed\n", checks, failures);
  return failures == 0 ? 0 : 1;
}
