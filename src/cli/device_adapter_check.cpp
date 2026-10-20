#include "core/input/device_adapter_protocol.hpp"

#include <nlohmann/json.hpp>

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>

namespace {

struct Options {
    std::filesystem::path trace_path;
    bool require_audio = false;
    bool pretty = false;
};

void print_usage(std::ostream& output) {
    output << "Usage: shinsoku-adapter-check [--trace PATH] [--require-audio] [--pretty]\n"
              "\n"
              "Validate a Shinsoku Device Adapter v1 JSONL event trace. When --trace is\n"
              "omitted, the trace is read from standard input. The command never launches\n"
              "or grants permissions to an adapter executable.\n";
}

Options parse_options(int argc, char** argv) {
    Options options;
    for (int index = 1; index < argc; ++index) {
        const std::string_view argument(argv[index]);
        if (argument == "--help" || argument == "-h") {
            print_usage(std::cout);
            std::exit(0);
        }
        if (argument == "--trace") {
            if (++index >= argc) {
                throw std::invalid_argument("--trace requires a path");
            }
            options.trace_path = argv[index];
        } else if (argument == "--require-audio") {
            options.require_audio = true;
        } else if (argument == "--pretty") {
            options.pretty = true;
        } else {
            throw std::invalid_argument("unknown argument: " + std::string(argument));
        }
    }
    return options;
}

}  // namespace

int main(int argc, char** argv) {
    try {
        const Options options = parse_options(argc, argv);
        std::ifstream file;
        std::istream* input = &std::cin;
        if (!options.trace_path.empty()) {
            file.open(options.trace_path, std::ios::binary);
            if (!file) {
                throw std::runtime_error("could not open trace: " + options.trace_path.string());
            }
            input = &file;
        }

        ohmytypeless::DeviceAdapterTraceValidator validator(options.require_audio);
        std::string line;
        while (std::getline(*input, line)) {
            if (!line.empty() && line.back() == '\r') {
                line.pop_back();
            }
            validator.accept_line(line);
        }
        if (input->bad()) {
            throw std::runtime_error("failed while reading the adapter trace");
        }

        const ohmytypeless::DeviceAdapterValidationReport report = validator.finish();
        std::cout << report.to_json().dump(options.pretty ? 2 : -1) << '\n';
        return report.ok ? 0 : 1;
    } catch (const std::exception& exception) {
        const nlohmann::json error{
            {"schema_version", 1},
            {"ok", false},
            {"errors", nlohmann::json::array({exception.what()})},
        };
        std::cerr << error.dump() << '\n';
        return 2;
    }
}
