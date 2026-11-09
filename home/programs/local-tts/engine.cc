#include <sherpa-onnx/c-api/cxx-api.h>

#include "pcm-stream.h"

#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>

int main(int argc, char **argv) {
  try {
    if (argc != 4) {
      throw std::runtime_error("expected MODEL OUTPUT-OR-DASH VERBOSE");
    }
    std::string model = argv[1];
    std::string output = argv[2];
    std::string text{std::istreambuf_iterator<char>(std::cin), {}};
    if (text.empty()) {
      throw std::runtime_error("empty input");
    }
    sherpa_onnx::cxx::OfflineTtsConfig config;
    config.model.kokoro.model = model + "/model.int8.onnx";
    config.model.kokoro.voices = model + "/voices.bin";
    config.model.kokoro.tokens = model + "/tokens.txt";
    config.model.kokoro.data_dir = model + "/espeak-ng-data";
    config.model.num_threads = 4;
    config.model.provider = "cpu";
    config.model.debug = std::string(argv[3]) == "1";
    auto engine = sherpa_onnx::cxx::OfflineTts::Create(config);
    if (!engine.Get()) {
      throw std::runtime_error("could not initialize Kokoro");
    }
    if (engine.SampleRate() != 24000) {
      throw std::runtime_error("expected 24000 Hz model");
    }
    sherpa_onnx::cxx::GenerationConfig generation;
    generation.sid = 1;
    generation.silence_scale = 0.2;
    bool failed = false;
    auto audio = engine.Generate(
        text, generation, output == "-" ? stream_audio : nullptr, &failed);
    if (failed || audio.samples.empty()) {
      throw std::runtime_error("audio generation or stream write failed");
    }
    if (output != "-" && !sherpa_onnx::cxx::WriteWave(
                             output, {audio.samples, audio.sample_rate})) {
      throw std::runtime_error("could not write WAV");
    }
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "speak engine: " << error.what() << '\n';
    return 1;
  }
}
