//
// DESCRIPTION:
//
// A 'grep'-like tool, which searches for a given phrase in the
// given files or standard input, skipping those found in the comments
// or string values.
//
// NOTES:
//  - C++11 raw string literals are not handled properly
//  - Lines and file are always printed (grep's -n option)
//  - Option -w is handled like in grep
//
// SYNOPSIS:
//
// cgrep [-w] PHRASE [files...]
//
// Copyleft (L) Google Gemini
// Modified by: Sektor van Skijlen

#include <iostream>
#include <fstream>
#include <string>
#include <string_view>
#include <deque>
#include <algorithm>
#include <cctype>

bool g_opt_words = false;

enum class State {
    Code,
    LineComment,
    BlockComment,
    StringLiteral,
    CharLiteral,
    RawStringLiteral
};

void grep_code_only(std::istream& file, const std::string& target, const std::string& filename) {

    std::string line;
    size_t line_num = 0;
    State state = State::Code;

    // Tracking variables for raw string literal states across lines
    std::string raw_delimiter = "";

    while (std::getline(file, line)) {
        line_num++;
        std::string code_only = "";
        code_only.reserve(line.size());

        bool escaped = false;

        for (size_t i = 0; i < line.size(); ++i) {
            char c = line[i];
            char next = (i + 1 < line.size()) ? line[i + 1] : '\0';

            switch (state) {
                case State::Code:
                    // Check for C++11 Raw String Literal: R"delim(
                    if (c == 'R' && next == '"') {
                        state = State::RawStringLiteral;
                        raw_delimiter = "";
                        i++; // Skip '"'

                        // Extract the delimiter sequence until '('
                        while (++i < line.size() && line[i] != '(') {
                            raw_delimiter += line[i];
                        }
                        // line[i] is now '(', the content starts after it
                    } else if (c == '/' && next == '/') {
                        state = State::LineComment;
                        i++;
                    } else if (c == '/' && next == '*') {
                        state = State::BlockComment;
                        i++;
                    } else if (c == '"') {
                        state = State::StringLiteral;
                        escaped = false;
                    } else if (c == '\'') {
                        state = State::CharLiteral;
                        escaped = false;
                    } else {
                        code_only += c;
                    }
                    break;

                case State::LineComment:
                    break; // Automatically resets at end of line

                case State::BlockComment:
                    if (c == '*' && next == '/') {
                        state = State::Code;
                        i++;
                    }
                    break;

                case State::StringLiteral:
                    if (escaped) {
                        escaped = false;
                    } else if (c == '\\') {
                        escaped = true;
                    } else if (c == '"') {
                        state = State::Code;
                    }
                    break;

                case State::CharLiteral:
                    if (escaped) {
                        escaped = false;
                    } else if (c == '\\') {
                        escaped = true;
                    } else if (c == '\'') {
                        state = State::Code;
                    }
                    break;

                case State::RawStringLiteral: {
                    // Raw string ends at: )delimiter"
                    if (c == ')') {
                        std::string_view remaining(line.c_str() + i + 1, line.size() - (i + 1));
                        // Check if the closing sequence matches delimiter + quote
                        if (remaining.rfind(raw_delimiter + "\"", 0) == 0) {
                            i += raw_delimiter.size() + 1; // Advance past delimiter and '"'
                            state = State::Code;
                        }
                    }
                    break;
                }
            }
        }

        if (state == State::LineComment) {
            state = State::Code;
        }
        // Search for the target phrase only in the filtered code structure
        if (!code_only.empty()) {
            size_t pos = std::string::npos;

            if (!g_opt_words) {
                pos = code_only.find(target);
            } else {
                // To find the whole words, search multiple times in a line
                // if need be, and if found, check the surroundings.
                size_t found = 0;
                for (;;)
                {
                    if (found >= code_only.size())
                        break;
                    found = code_only.find(target, found);
                    if (found == std::string::npos) // not found
                        break;
                    if (found > 0) {
                        char c = code_only[found-1];
                        // Additionally check the preceding character
                        if (isalnum(c) || c == '_') {
                            ++found;
                            continue; // Failed search; search again.
                        }
                    }
                    size_t found_out = found + target.size();
                    if (found_out < code_only.size())
                    {
                        char c = code_only[found_out];
                        if (isalnum(c) || c == '_') {
                            ++found;
                            continue; // Failed search; search again.
                        }
                    }
                    // Passed both checks, so it's found
                    pos = found;
                    break;
                }
            }

            if (pos != std::string::npos) {
                std::cout << filename << ":" << line_num << ": " << line << "\n";
            }
        }
    }
}

void grep_code_only(const std::string& filename, const std::string& target) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error: Could not open file " << filename << "\n";
        return;
    }

    return grep_code_only(file, target, filename);
}

using namespace std;

template<class Value>
inline Value try_pull(std::deque<Value>& d, const Value& deflt = Value()) {
    if (d.empty())
        return deflt;
    Value ret = d.front();
    d.pop_front();
    return ret;
}

int main(int argc, char* argv[]) {
    deque<string> args(argv + 1, argv + argc);

    // XXX here handle options if any; leave args as "free arguments"

    string phrase;
    for (;;)
    {
        phrase = try_pull(args);
        if (phrase == "-w")
        {
            ::g_opt_words = true;
            continue;
        }
        // Handle also other options.
        break;
    }

    if (phrase == "") {
        std::cout << "Usage: " << argv[0] << " <search_phrase> <file_path>\n";
        return 1;
    }

    if (args.empty()) { // use stdin
        grep_code_only(std::cin, args[0], "STDIN");
    } else {
        for (const auto& fn: args) {
            grep_code_only(fn, phrase);
        }
    }
    return 0;
}
