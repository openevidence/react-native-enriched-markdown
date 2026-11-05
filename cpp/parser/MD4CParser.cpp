#include "MD4CParser.hpp"
#include "../md4c/md4c.h"
#include <cctype>
#include <cstring>
#include <cstdio>
#include <vector>

namespace Markdown {

class MD4CParser::Impl {
public:
  std::shared_ptr<MarkdownASTNode> root;
  std::vector<std::shared_ptr<MarkdownASTNode>> nodeStack;
  std::string currentText;
  const char *inputText = nullptr;
  bool doseTags = false;

  static const std::string ATTR_LEVEL;
  static const std::string ATTR_URL;
  static const std::string ATTR_TITLE;
  static const std::string ATTR_FENCE_CHAR;
  static const std::string ATTR_LANGUAGE;
  static const std::string ATTR_IS_TASK;
  static const std::string ATTR_TASK_CHECKED;

  void reset(size_t estimatedDepth) {
    root = std::make_shared<MarkdownASTNode>(NodeType::Document);
    nodeStack.clear();
    // Reserve based on estimated depth, with reasonable bounds
    // Typical markdown has 5-15 levels, but can go deeper with nested structures
    // Cap at 128 to avoid excessive memory for extreme cases
    nodeStack.reserve(std::min(estimatedDepth, static_cast<size_t>(128)));
    nodeStack.push_back(root);
    currentText.clear();
    currentText.reserve(256);
  }

  void flushText() {
    if (!currentText.empty() && !nodeStack.empty()) {
      auto textNode = std::make_shared<MarkdownASTNode>(NodeType::Text);
      textNode->content = std::move(currentText);
      nodeStack.back()->addChild(std::move(textNode));
      currentText.clear();
    }
  }

  void pushNode(std::shared_ptr<MarkdownASTNode> node) {
    flushText();
    if (node && !nodeStack.empty()) {
      nodeStack.back()->addChild(node);
      nodeStack.push_back(std::move(node));
    }
  }

  void popNode() {
    flushText();
    if (nodeStack.size() > 1) {
      nodeStack.pop_back();
    }
  }

  void addInlineNode(std::shared_ptr<MarkdownASTNode> node) {
    flushText();
    if (node && !nodeStack.empty()) {
      nodeStack.back()->addChild(node);
    }
  }

  // Longest attribute value kept on a Dose node. The app writes short ids,
  // states and labels; a longer value is cut rather than copied whole.
  static constexpr size_t kMaxDoseAttributeLength = 512;

  static bool isTagNameEnd(char c) {
    return c == '>' || c == '/' || c == ' ' || c == '\t' || c == '\n' || c == '\r';
  }

  // True for "<dose>" or "<dose " + attributes + ">", case-insensitive.
  // A self-closing "<dose/>" carries no words to mark, so it is not an opener.
  static bool isDoseOpenTag(const std::string &tag) {
    if (tag.size() < 6 || tag[0] != '<')
      return false;
    static const char *name = "dose";
    for (size_t i = 0; i < 4; ++i) {
      if (std::tolower(static_cast<unsigned char>(tag[i + 1])) != name[i])
        return false;
    }
    if (!isTagNameEnd(tag[5]))
      return false;
    size_t last = tag.find_last_not_of(" \t\n\r");
    if (last == std::string::npos || tag[last] != '>')
      return false;
    size_t prev = last > 0 ? tag.find_last_not_of(" \t\n\r", last - 1) : std::string::npos;
    return !(prev != std::string::npos && prev >= 5 && tag[prev] == '/');
  }

  static bool isDoseCloseTag(const std::string &normalizedLower) { return normalizedLower == "</dose>"; }

  // Reads name="value", name='value' and name=value pairs after "<dose".
  static void parseDoseAttributes(const std::string &tag, MarkdownASTNode &node) {
    size_t end = tag.size();
    while (end > 0 && (tag[end - 1] == '>' || tag[end - 1] == ' ' || tag[end - 1] == '\t' || tag[end - 1] == '\n' ||
                       tag[end - 1] == '\r')) {
      --end;
    }
    size_t i = 5; // past "<dose"
    auto isSpace = [](char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; };
    auto isNameChar = [](char c) {
      return std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '-' || c == ':' || c == '.';
    };
    while (i < end) {
      while (i < end && isSpace(tag[i]))
        ++i;
      size_t nameStart = i;
      while (i < end && isNameChar(tag[i]))
        ++i;
      if (i == nameStart) {
        ++i; // skip a stray character such as '/'
        continue;
      }
      std::string attrName;
      attrName.reserve(i - nameStart);
      for (size_t k = nameStart; k < i; ++k) {
        attrName.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(tag[k]))));
      }
      while (i < end && isSpace(tag[i]))
        ++i;
      std::string value;
      if (i < end && tag[i] == '=') {
        ++i;
        while (i < end && isSpace(tag[i]))
          ++i;
        if (i < end && (tag[i] == '"' || tag[i] == '\'')) {
          char quote = tag[i++];
          size_t valueStart = i;
          while (i < end && tag[i] != quote)
            ++i;
          value = tag.substr(valueStart, i - valueStart);
          if (i < end)
            ++i; // closing quote
        } else {
          size_t valueStart = i;
          while (i < end && !isSpace(tag[i]))
            ++i;
          value = tag.substr(valueStart, i - valueStart);
        }
      }
      if (value.size() > kMaxDoseAttributeLength) {
        value.resize(kMaxDoseAttributeLength);
      }
      node.setAttribute(attrName, value);
    }
  }

  // A <dose> opened inside a span or block that ends before its </dose> is
  // closed with that span or block, so the mark never swallows what follows.
  void closeDanglingDoseNodes() {
    while (nodeStack.size() > 1 && nodeStack.back()->type == NodeType::Dose) {
      popNode();
    }
  }

  // Map recognized inline HTML tags to AST nodes (Strong, Emphasis, etc.)
  // Unrecognized tags are silently dropped (their text content still appears).
  void handleInlineHtml(const std::string &tag) {
    if (doseTags && isDoseOpenTag(tag)) {
      auto node = std::make_shared<MarkdownASTNode>(NodeType::Dose);
      parseDoseAttributes(tag, *node);
      pushNode(node);
      return;
    }

    // Normalize: lowercase comparison, trim whitespace
    std::string lower;
    lower.reserve(tag.size());
    for (char c : tag) {
      if (c != ' ' && c != '\t' && c != '\n' && c != '\r') {
        lower.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));
      }
    }

    // Opening tags → push node
    if (lower == "<strong>" || lower == "<b>") {
      pushNode(std::make_shared<MarkdownASTNode>(NodeType::Strong));
    } else if (lower == "<em>" || lower == "<i>") {
      pushNode(std::make_shared<MarkdownASTNode>(NodeType::Emphasis));
    }
    // A </dose> closes only an open Dose; a stray one is dropped.
    else if (isDoseCloseTag(lower)) {
      if (doseTags && !nodeStack.empty() && nodeStack.back()->type == NodeType::Dose) {
        popNode();
      }
    }
    // Closing tags → pop node
    else if (lower == "</strong>" || lower == "</b>" ||
             lower == "</em>" || lower == "</i>") {
      popNode();
    }
    // Self-closing / void tags
    else if (lower == "<br>" || lower == "<br/>" || lower == "<br/>") {
      addInlineNode(std::make_shared<MarkdownASTNode>(NodeType::LineBreak));
    }
    // Unrecognized tags: silently drop (content between them still renders)
  }

  std::string getAttributeText(const MD_ATTRIBUTE *attr) {
    if (!attr || attr->size == 0 || !attr->text)
      return {};

    // Use string constructor directly - let SSO handle small strings efficiently
    // Empty return {} avoids allocating empty string object
    return std::string(attr->text, attr->size);
  }

  static int enterBlock(MD_BLOCKTYPE type, void *detail, void *userdata) {
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    switch (type) {
      case MD_BLOCK_DOC:
        // Document node already created in reset()
        break;

      case MD_BLOCK_P: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Paragraph));
        break;
      }

      case MD_BLOCK_H: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Heading);
        if (detail) {
          auto *h = static_cast<MD_BLOCK_H_DETAIL *>(detail);
          int level = static_cast<int>(h->level);
          // Clamp level to valid range (1-6)
          level = (level < 1) ? 1 : (level > 6) ? 6 : level;
          // Use char conversion for small integers (1-6)
          // Avoids std::to_string() allocation overhead
          char levelStr[2] = {static_cast<char>('0' + level), '\0'};
          node->setAttribute(ATTR_LEVEL, levelStr);
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_QUOTE: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Blockquote));
        break;
      }

      case MD_BLOCK_UL: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::UnorderedList));
        break;
      }

      case MD_BLOCK_OL: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::OrderedList));
        break;
      }

      case MD_BLOCK_LI: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::ListItem);
        if (detail) {
          auto *li = static_cast<MD_BLOCK_LI_DETAIL *>(detail);
          if (li->is_task) {
            node->setAttribute(ATTR_IS_TASK, "true");
            node->setAttribute(ATTR_TASK_CHECKED, (li->task_mark == 'x' || li->task_mark == 'X') ? "true" : "false");
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_CODE: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::CodeBlock);
        if (detail) {
          auto *codeDetail = static_cast<MD_BLOCK_CODE_DETAIL *>(detail);
          // Extract fence character (if fenced code block)
          if (codeDetail->fence_char != 0) {
            char fenceStr[2] = {static_cast<char>(codeDetail->fence_char), '\0'};
            node->setAttribute(ATTR_FENCE_CHAR, fenceStr);
          }
          // Extract language from lang attribute
          std::string lang = impl->getAttributeText(&codeDetail->lang);
          if (!lang.empty()) {
            node->setAttribute(ATTR_LANGUAGE, lang);
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_HR: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::ThematicBreak));
        break;
      }

      case MD_BLOCK_TABLE: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Table);
        if (detail) {
          auto *tableDetail = static_cast<MD_BLOCK_TABLE_DETAIL *>(detail);
          node->setAttribute("colCount", std::to_string(tableDetail->col_count));
          node->setAttribute("headRowCount", std::to_string(tableDetail->head_row_count));
          node->setAttribute("bodyRowCount", std::to_string(tableDetail->body_row_count));
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_THEAD: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::TableHead));
        break;
      }

      case MD_BLOCK_TBODY: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::TableBody));
        break;
      }

      case MD_BLOCK_TR: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::TableRow));
        break;
      }

      case MD_BLOCK_TH:
      case MD_BLOCK_TD: {
        auto node =
            std::make_shared<MarkdownASTNode>(type == MD_BLOCK_TH ? NodeType::TableHeaderCell : NodeType::TableCell);
        if (detail) {
          auto *tdDetail = static_cast<MD_BLOCK_TD_DETAIL *>(detail);
          const char *alignStr;
          switch (tdDetail->align) {
            case MD_ALIGN_LEFT:
              alignStr = "left";
              break;
            case MD_ALIGN_CENTER:
              alignStr = "center";
              break;
            case MD_ALIGN_RIGHT:
              alignStr = "right";
              break;
            default:
              alignStr = "default";
              break;
          }
          node->setAttribute("align", alignStr);
        }
        impl->pushNode(node);
        break;
      }

      default:
        // Other block types not yet implemented
        break;
    }

    return 0;
  }

  static int leaveBlock(MD_BLOCKTYPE type, void *detail, void *userdata) {
    (void)detail;
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    if (type != MD_BLOCK_DOC && !impl->nodeStack.empty()) {
      impl->closeDanglingDoseNodes();
      impl->popNode();
    }

    return 0;
  }

  static int enterSpan(MD_SPANTYPE type, void *detail, void *userdata) {
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    switch (type) {
      case MD_SPAN_A: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Link);
        if (detail) {
          auto *linkDetail = static_cast<MD_SPAN_A_DETAIL *>(detail);
          std::string url = impl->getAttributeText(&linkDetail->href);
          if (!url.empty()) {
            node->setAttribute(ATTR_URL, url);
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_SPAN_STRONG: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Strong));
        break;
      }

      case MD_SPAN_EM: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Emphasis));
        break;
      }

      case MD_SPAN_U: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Underline));
        break;
      }

      case MD_SPAN_CODE: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Code));
        break;
      }

      case MD_SPAN_DEL: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Strikethrough));
        break;
      }

      case MD_SPAN_IMG: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Image);
        if (detail) {
          auto *imgDetail = static_cast<MD_SPAN_IMG_DETAIL *>(detail);
          std::string url = impl->getAttributeText(&imgDetail->src);
          if (!url.empty()) {
            node->setAttribute(ATTR_URL, url);
          }
          std::string title = impl->getAttributeText(&imgDetail->title);
          if (!title.empty()) {
            node->setAttribute(ATTR_TITLE, title);
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_SPAN_LATEXMATH: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::LatexMathInline));
        break;
      }

      case MD_SPAN_LATEXMATH_DISPLAY: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::LatexMathDisplay));
        break;
      }

      case MD_SPAN_SPOILER: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Spoiler));
        break;
      }

      default:
        break;
    }

    return 0;
  }

  static int leaveSpan(MD_SPANTYPE type, void *detail, void *userdata) {
    (void)detail;
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    if (!impl->nodeStack.empty()) {
      impl->closeDanglingDoseNodes();
      impl->popNode();
    }

    return 0;
  }

  static int text(MD_TEXTTYPE type, const MD_CHAR *text, MD_SIZE size, void *userdata) {
    if (!userdata || !text || size == 0)
      return 0;
    auto *impl = static_cast<Impl *>(userdata);

    // Handle soft/hard line breaks
    if (type == MD_TEXT_SOFTBR || type == MD_TEXT_BR) {
      auto brNode = std::make_shared<MarkdownASTNode>(NodeType::LineBreak);
      impl->addInlineNode(brNode);
      return 0;
    }

    // Handle text content (normal text, code text, LaTeX math, etc.)
    if (type == MD_TEXT_NORMAL || type == MD_TEXT_CODE || type == MD_TEXT_LATEXMATH) {
      impl->currentText.append(text, size);
    }

    // Handle HTML entities (&amp; &nbsp; etc.) — decode to literal text
    if (type == MD_TEXT_ENTITY) {
      impl->currentText.append(text, size);
    }

    // Handle inline HTML tags — map recognized tags to AST nodes
    if (type == MD_TEXT_HTML) {
      std::string tag(text, size);
      impl->handleInlineHtml(tag);
    }

    return 0;
  }
};

namespace {

bool isDisplayMathNode(const MarkdownASTNode &node) {
  return node.type == NodeType::LatexMathDisplay;
}

bool isSeparatorNode(const MarkdownASTNode &node) {
  return node.type == NodeType::LineBreak ||
         (node.type == NodeType::Text && node.content.find_first_not_of(" \t\n\r") == std::string::npos);
}

// md4c treats $$...$$ as an inline span, so when display math appears on a line
// directly after text (no blank line), md4c merges them into a single Paragraph.
// This function finds the trailing run of LatexMathDisplay nodes (possibly
// interspersed with LineBreak / whitespace separators) at the end of a paragraph's
// children. Returns the index where the trailing run starts, or children.size()
// if there is nothing to promote.
size_t findTrailingDisplayMathRun(const std::vector<std::shared_ptr<MarkdownASTNode>> &children) {
  size_t trailingRunStart = children.size();
  bool hasDisplayMath = false;

  for (size_t j = children.size(); j > 0; --j) {
    auto &node = children[j - 1];
    if (isDisplayMathNode(*node)) {
      trailingRunStart = j - 1;
      hasDisplayMath = true;
    } else if (isSeparatorNode(*node) && hasDisplayMath) {
      trailingRunStart = j - 1;
    } else {
      break;
    }
  }

  return hasDisplayMath ? trailingRunStart : children.size();
}

// Collect only the LatexMathDisplay nodes from a range, skipping separators.
std::vector<std::shared_ptr<MarkdownASTNode>>
collectDisplayMathNodes(const std::vector<std::shared_ptr<MarkdownASTNode>> &children, size_t from) {
  std::vector<std::shared_ptr<MarkdownASTNode>> result;
  for (size_t j = from; j < children.size(); ++j) {
    if (isDisplayMathNode(*children[j]))
      result.push_back(children[j]);
  }
  return result;
}

// Post-processing: extract [[N,M,...]] citation patterns from Text nodes and
// replace them with Citation nodes. This mirrors the web pipeline's remarkCitations
// plugin which creates OECitationMdNode from [[N]] patterns.
//
// A Text node like "See evidence [[1,2]] and [[3]]." becomes:
//   Text("See evidence "), Citation("1,2"), Text(" and "), Citation("3"), Text(".")

// Citation format: [[numbers|label|faviconUrl]]
// - numbers: comma-separated digits (e.g. "1,2,3")
// - label: display text for the chip (e.g. "Radiographics")
// - faviconUrl: optional URL for favicon image
// All fields separated by '|'. Label and faviconUrl may be empty.
// Falls back to simple [[numbers]] format (no pipes) for backward compat.
struct CitationParseResult {
  std::string numbers;
  std::string label;
  std::string faviconUrl;
};

static size_t tryCitationAt(const std::string &text, size_t pos, CitationParseResult &result) {
  size_t len = text.size();
  if (pos + 4 >= len) return 0;
  if (text[pos] != '[' || text[pos + 1] != '[') return 0;

  // Find the closing ]]
  size_t start = pos + 2;
  size_t end = start;
  while (end < len) {
    if (end + 1 < len && text[end] == ']' && text[end + 1] == ']') break;
    end++;
  }
  if (end >= len || text[end] != ']') return 0;

  // Content between [[ and ]]
  std::string content = text.substr(start, end - start);
  if (content.empty()) return 0;

  // Split on '|' delimiter
  std::string numbersPart;
  result.label.clear();
  result.faviconUrl.clear();

  size_t pipe1 = content.find('|');
  if (pipe1 != std::string::npos) {
    numbersPart = content.substr(0, pipe1);
    size_t pipe2 = content.find('|', pipe1 + 1);
    if (pipe2 != std::string::npos) {
      result.label = content.substr(pipe1 + 1, pipe2 - pipe1 - 1);
      result.faviconUrl = content.substr(pipe2 + 1);
    } else {
      result.label = content.substr(pipe1 + 1);
    }
  } else {
    numbersPart = content;
  }

  // Validate numbers part: must contain at least one digit
  bool hasDigit = false;
  result.numbers.clear();
  for (char c : numbersPart) {
    if (c >= '0' && c <= '9') { hasDigit = true; result.numbers.push_back(c); }
    else if (c == ',') { result.numbers.push_back(c); }
    // skip spaces
  }
  if (!hasDigit) return 0;

  return end + 2; // past the closing ]]
}

void extractCitationsFromTextNodes(MarkdownASTNode &node) {
  auto &children = node.children;

  for (size_t i = 0; i < children.size(); ++i) {
    auto &child = children[i];

    if (child->type == NodeType::Text && !child->content.empty()) {
      const std::string &text = child->content;

      if (text.find("[[") == std::string::npos) {
        continue;
      }

      std::vector<std::shared_ptr<MarkdownASTNode>> replacements;
      size_t lastPos = 0;
      size_t pos = 0;
      CitationParseResult citResult;

      while (pos < text.size()) {
        size_t found = text.find("[[", pos);
        if (found == std::string::npos) break;

        size_t citEnd = tryCitationAt(text, found, citResult);
        if (citEnd == 0) {
          pos = found + 2;
          continue;
        }

        if (found > lastPos) {
          auto textNode = std::make_shared<MarkdownASTNode>(NodeType::Text);
          textNode->content = text.substr(lastPos, found - lastPos);
          replacements.push_back(std::move(textNode));
        }

        auto citationNode = std::make_shared<MarkdownASTNode>(NodeType::Citation);
        // Use label as display content if available, otherwise numbers
        citationNode->content = citResult.label.empty() ? citResult.numbers : citResult.label;
        citationNode->setAttribute("numbers", citResult.numbers);
        if (!citResult.label.empty()) {
          citationNode->setAttribute("label", citResult.label);
        }
        if (!citResult.faviconUrl.empty()) {
          citationNode->setAttribute("faviconUrl", citResult.faviconUrl);
        }
        replacements.push_back(std::move(citationNode));

        lastPos = citEnd;
        pos = citEnd;
      }

      if (replacements.empty()) {
        continue;
      }

      if (lastPos < text.size()) {
        auto textNode = std::make_shared<MarkdownASTNode>(NodeType::Text);
        textNode->content = text.substr(lastPos);
        replacements.push_back(std::move(textNode));
      }

      auto insertPos = children.erase(children.begin() + static_cast<ptrdiff_t>(i));
      children.insert(insertPos, replacements.begin(), replacements.end());
      i += replacements.size() - 1;
    } else {
      extractCitationsFromTextNodes(*child);
    }
  }
}

// md4c wraps $$...$$ (display math) as inline spans inside a Paragraph. When they
// appear on consecutive lines without a blank separator, md4c merges them — along
// with any preceding text — into a single Paragraph with LineBreak nodes between them.
//
// This post-processing step walks the document's top-level children and promotes
// trailing LatexMathDisplay nodes out of their parent Paragraph so that the
// rendering layer sees them as top-level block elements.
//
// Two cases:
//  (a) Pure: every child is display math or a separator → replace paragraph entirely.
//  (b) Mixed: leading text followed by display math → keep text in the paragraph,
//      splice the display math nodes as siblings after it.
void promoteDisplayMathFromParagraphs(MarkdownASTNode &root) {
  auto &children = root.children;

  for (size_t i = 0; i < children.size();) {
    auto &paragraph = children[i];
    if (paragraph->type != NodeType::Paragraph || paragraph->children.empty()) {
      ++i;
      continue;
    }

    auto &paragraphChildren = paragraph->children;
    size_t trailingRunStart = findTrailingDisplayMathRun(paragraphChildren);

    if (trailingRunStart >= paragraphChildren.size()) {
      ++i;
      continue;
    }

    auto promoted = collectDisplayMathNodes(paragraphChildren, trailingRunStart);

    if (trailingRunStart == 0) {
      auto position = children.erase(children.begin() + static_cast<ptrdiff_t>(i));
      children.insert(position, promoted.begin(), promoted.end());
      i += promoted.size();
    } else {
      paragraphChildren.erase(paragraphChildren.begin() + static_cast<ptrdiff_t>(trailingRunStart),
                              paragraphChildren.end());
      while (!paragraphChildren.empty() && isSeparatorNode(*paragraphChildren.back())) {
        paragraphChildren.pop_back();
      }
      auto position = children.begin() + static_cast<ptrdiff_t>(i) + 1;
      children.insert(position, promoted.begin(), promoted.end());
      i += 1 + promoted.size();
    }
  }
}

} // anonymous namespace

MD4CParser::MD4CParser() : impl_(std::make_unique<Impl>()) {}

MD4CParser::~MD4CParser() = default;

std::shared_ptr<MarkdownASTNode> MD4CParser::parse(const std::string &markdown, const Md4cFlags &md4cFlags) {
  if (markdown.empty()) {
    return std::make_shared<MarkdownASTNode>(NodeType::Document);
  }

  // Estimate stack depth based on markdown size
  // Heuristic: ~1 nesting level per 500-1000 characters for typical markdown
  // This is a rough estimate - actual depth depends on structure, not just size
  // Base depth of 12 covers typical nested structures (blockquotes, future lists)
  size_t estimatedDepth = 12; // Base depth for small documents
  if (markdown.size() > 1000) {
    // Scale up for larger documents, but cap the growth
    estimatedDepth = std::min(static_cast<size_t>(12 + (markdown.size() / 1000)), static_cast<size_t>(64));
  }

  impl_->reset(estimatedDepth);
  impl_->inputText = markdown.c_str();
  impl_->doseTags = md4cFlags.doseTags;

  unsigned flags = MD_FLAG_STRIKETHROUGH | MD_FLAG_TABLES | MD_FLAG_TASKLISTS | MD_FLAG_SPOILER;
  if (md4cFlags.permissiveAutolinks) {
    flags |= MD_FLAG_PERMISSIVEAUTOLINKS;
  }
  if (md4cFlags.latexMath) {
    flags |= MD_FLAG_LATEXMATHSPANS;
  }
  if (md4cFlags.underline) {
    flags |= MD_FLAG_UNDERLINE;
  }
  if (md4cFlags.singleTilde) {
    flags |= MD_FLAG_SINGLETILDESTRIKETHROUGH;
  }

  // Configure MD4C parser with callbacks
  MD_PARSER parser = {
      0, // abi_version
      flags,   &Impl::enterBlock, &Impl::leaveBlock, &Impl::enterSpan, &Impl::leaveSpan, &Impl::text,
      nullptr, // debug_log
      nullptr  // syntax
  };

  // Parse the markdown
  int result = md_parse(markdown.c_str(), static_cast<MD_SIZE>(markdown.size()), &parser, impl_.get());

  if (result != 0) {
    // Parsing failed, return empty document
    return std::make_shared<MarkdownASTNode>(NodeType::Document);
  }

  impl_->flushText();

  if (impl_->root) {
    extractCitationsFromTextNodes(*impl_->root);
    promoteDisplayMathFromParagraphs(*impl_->root);
  }

  return impl_->root ? impl_->root : std::make_shared<MarkdownASTNode>(NodeType::Document);
}

// Static member definitions
const std::string MD4CParser::Impl::ATTR_LEVEL = "level";
const std::string MD4CParser::Impl::ATTR_URL = "url";
const std::string MD4CParser::Impl::ATTR_TITLE = "title";
const std::string MD4CParser::Impl::ATTR_FENCE_CHAR = "fenceChar";
const std::string MD4CParser::Impl::ATTR_LANGUAGE = "language";
const std::string MD4CParser::Impl::ATTR_IS_TASK = "isTask";
const std::string MD4CParser::Impl::ATTR_TASK_CHECKED = "taskChecked";

} // namespace Markdown