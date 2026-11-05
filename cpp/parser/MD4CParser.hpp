#pragma once

#include "MarkdownASTNode.hpp"
#include <string>
#include <memory>

namespace Markdown {

struct Md4cFlags {
    bool underline = false;
    bool latexMath = true;
    bool permissiveAutolinks = true;
    bool singleTilde = false;
    // Parse OE's inline <dose …>…</dose> tags into Dose nodes. Off by default:
    // a platform without a dose renderer keeps today's behaviour, where the
    // unknown tag is dropped and its words render as plain text.
    bool doseTags = false;
};

class MD4CParser {
public:
    MD4CParser();
    ~MD4CParser();

    // Parse markdown string and return AST root node
    std::shared_ptr<MarkdownASTNode> parse(const std::string& markdown, const Md4cFlags& flags = Md4cFlags{});

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace Markdown

