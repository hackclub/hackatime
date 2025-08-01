#ifndef HACKATIME_DOCTOR_H
#define HACKATIME_DOCTOR_H

#include <string>
#include <vector>

#define COLOR_RED     "\x1b[31m"
#define COLOR_GREEN   "\x1b[32m"
#define COLOR_YELLOW  "\x1b[33m"
#define COLOR_BLUE    "\x1b[34m"
#define COLOR_RESET   "\x1b[0m"

struct CheckResult {
    bool success;
    std::string message;
    std::string name;

    CheckResult(bool s, std::string m, std::string n = "")
    : success(s), message(std::move(m)), name(std::move(n)) {}
};

CheckResult check_wakatime_config();
CheckResult check_git_installed();
CheckResult check_node_installed();
CheckResult check_folder_structure();
CheckResult check_api_tokens();
void print_summary(const std::vector<CheckResult>& results);
void suggest_debug_tips(const std::vector<CheckResult>& results);
int run_hackatime_doctor(int argc, char* argv[]);

#endif
