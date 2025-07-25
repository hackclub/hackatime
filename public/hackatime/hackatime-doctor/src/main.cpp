#include "hackatime_doctor.h"
#include "main.h"

void print_help() {
    std::cout <<
        "hackatime-doctor - Diagnostic tool for HackTime environments\n"
        "Usage:\n"
        "  hackatime-doctor [options]\n\n"
        "Options:\n"
        "  -f, --full-check         Performs extended environment checks\n"
        "  -j, --json [file]    Export results as JSON\n"
        "  -c, --csv  [file]    Export results as CSV\n"
        "  -h, --help           Show this help message\n";
}

void export_to_json(const std::vector<CheckResult>& results, const std::string& filename) {
    json j;
    for (const auto& result : results) {
        j[result.name] = {
            {"success", result.success},
            {"message", result.message},
            {"timestamp", std::time(nullptr)}
        };
    }

    std::ofstream out(filename);
    if (!out) {
        throw std::runtime_error("Failed to open " + filename + " for writing");
    }
    out << j.dump(4);  
}

void export_to_csv(const std::vector<CheckResult>& results, const std::string& filename) {
    std::ofstream out(filename);
    if (!out) {
        throw std::runtime_error("Failed to open " + filename + " for writing");
    }

    out << "Check,Status,Message\n";
    
    for (const auto& result : results) {
        out << std::quoted(result.name) << ","
            << (result.success ? "PASS" : "FAIL") << ","
            << std::quoted(result.message) << "\n";
    }
}

bool has_failures(const std::vector<CheckResult>& results) {
    return std::any_of(results.begin(), results.end(), 
        [](const auto& r) { return !r.success; });
}

int run_hackatime_doctor(int argc, char* argv[]) {
    std::cout << COLOR_BLUE << "⚕️ HackaTime Doctor - Checking your development environment...\n" << COLOR_RESET;

    bool export_json = false;
    bool export_csv = false;
    bool full_check = false;
    std::string output_file;
    std::vector<std::string> unknown_args;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        
        if (arg == "--json" || arg == "-j") {
            export_json = true;
            if (i+1 < argc && argv[i+1][0] != '-') {
                output_file = argv[++i];
            }
        }
        else if (arg == "--csv" || arg == "-c") {
            export_csv = true;
            if (i+1 < argc && argv[i+1][0] != '-') {
                output_file = argv[++i];
            }
        }
        else if (arg == "--full-check" || arg == "-f") {
            full_check = true;
        }
        else if (arg == "--help" || arg == "-h") {
            print_help();
            return 0;
        }
        else {
            unknown_args.push_back(arg);
        }
    }

    if (!unknown_args.empty()) {
        std::cerr << "Error: Unknown arguments:\n";
        for (const auto& arg : unknown_args) {
            std::cerr << "  " << arg << "\n";
        }
        std::cerr << "\nUsage:\n";
        print_help();
        return 1;
    }
    
    std::vector<CheckResult> results = {
        check_git_installed(),
        check_wakatime_config(),
        check_api_tokens()
    };

    if (full_check) {
        results.push_back(check_node_installed());
        results.push_back(check_folder_structure());
    }

    try {
        if (export_json) {
            std::string filename = output_file.empty() ? "hackatime-report.json" : output_file;
            export_to_json(results, filename);
            std::cout << "✓ Report saved to " << filename << "\n";
            return has_failures(results) ? 1 : 0;
        } 
        else if (export_csv) {
            std::string filename = output_file.empty() ? "hackatime-report.csv" : output_file;
            export_to_csv(results, filename);
            std::cout << "✓ Report saved to " << filename << "\n";
            return has_failures(results) ? 1 : 0;
        } 
        else {
            print_summary(results);
            if (has_failures(results)) {
                suggest_debug_tips(results);
                return 1;
            }
            return 0;
        }
    } 
    catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 2;
    }
}

int main(int argc, char* argv[]) {
    try {
        run_hackatime_doctor(argc, argv);
        return 0;
    } 
    catch (const std::exception& e) {
        std::cerr << "Fatal error: " << e.what() << "\n";
        return 2;
    }
}
