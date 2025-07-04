#include "hackatime_doctor.h"
#include "output.h"

void print_summary(const std::vector<CheckResult>& results) {
    std::cout << "\n" << COLOR_BLUE << "=== Check Summary ===\n" << COLOR_RESET;
    
    int success_count = 0;
    bool git_failed = false;
    bool node_failed = false;
    bool folders_failed = false;
    bool token_failed = false;

    for (const auto& result : results) {
        if (result.success) {
            success_count++;
        } else {
            if (result.message.find("Git") != std::string::npos) git_failed = true;
            if (result.message.find("Node") != std::string::npos) node_failed = true;
            if (result.message.find("folder") != std::string::npos) folders_failed = true;
            if (result.message.find("API") != std::string::npos) token_failed = true;
        }
    }

    for (const auto& result : results) {
        if (result.success) {
            std::cout << COLOR_GREEN << "[✓] " << result.message << COLOR_RESET << "\n";
        } else {
            std::cout << COLOR_RED << "[✗] " << result.message << COLOR_RESET << "\n";
        }
    }

    std::cout << "\n" << success_count << "/" << results.size() << " checks passed\n\n";

    if (static_cast<size_t>(success_count) == results.size()) {
        std::cout << COLOR_GREEN << "🎉 Everything looks perfect! You're ready to hack!\n" << COLOR_RESET;
    } else {
        std::cout << COLOR_YELLOW << "🔍 Focus Areas:\n" << COLOR_RESET;
        if (git_failed) std::cout << "- Git installation needs attention\n";
        if (node_failed) std::cout << "- Node.js setup requires fixes\n";
        if (folders_failed) std::cout << "- Project structure is incomplete\n";
        if (token_failed) std::cout << "- API token configuration is invalid\n";
    }
}

void suggest_debug_tips(const std::vector<CheckResult>& results) {
    bool needs_git_help = false;
    bool needs_node_help = false;
    bool needs_folder_help = false;
    bool needs_token_help = false;

    for (const auto& result : results) {
      if (!result.success) {
          if (result.name == "git_check") needs_git_help = true;
          if (result.name == "nodejs_check") needs_node_help = true;
          if (result.name == "folder_structure_check") needs_folder_help = true;
          if (result.name == "api_connection_check") needs_token_help = true;
      }
    }

    std::cout << COLOR_YELLOW << "💡 Targeted Debug Tips:\n" << COLOR_RESET;
    
    if (needs_git_help) {
        std::cout << COLOR_YELLOW << "1. Git Issues:\n"
                  << "   - Install: https://git-scm.com/downloads or if you are on linux/mac please use your respective package managers\n"
                  << "   - Verify PATH: Run 'which git'\n"
                  << COLOR_RESET;
    }

    if (needs_token_help) {
        std::cout << COLOR_YELLOW << "4. API Configuration Issues:\n"
                  << "   - Follow instructions from: https://hackatime.hackclub.com/my/wakatime_setup\n"
                  << COLOR_RESET;
    }

    if (needs_node_help) {
        std::cout << COLOR_YELLOW << "2. Node.js Issues:\n"
                  << "   - Install NodeJS: https://nodejs.org/ or if you are on linux/mac please use your respective package managers\n"
                  << "   - Check version: 'node --version' (Need v16+)\n"
                  << COLOR_RESET;
    }

    if (needs_folder_help) {
        std::cout << COLOR_YELLOW << "3. Missing Files/Folders:\n"
                  << "   - Expected: README.md, .gitignore and LICENSE\n"
                  << "   - Try: 'These files are essential for any git project please search up what these are if you havent heard of it'\n"
                  << COLOR_RESET;
    }

    if (needs_git_help || needs_node_help || needs_folder_help || needs_token_help) {
        std::cout << COLOR_YELLOW << "\n🛠️  General Troubleshooting:\n"
                  << "   - Restart your terminal after installations\n"
                  << "   - Verify current directory is the project root\n"
                  << "   - Check file permissions\n"
                  << COLOR_RESET;
    }
}

