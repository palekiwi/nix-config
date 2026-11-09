#include <sherpa-onnx/c-api/cxx-api.h>

#include "pcm-stream.h"

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>

using Clock = std::chrono::steady_clock;

struct PilotCallback {
  Clock::time_point started;
  bool first = true;
  bool failed = false;
  bool playback;
};

double seconds(Clock::time_point started) {
  return std::chrono::duration<double>(Clock::now() - started).count();
}

int32_t pilot_audio(const float *samples, int32_t count, float progress,
                    void *arg) {
  auto &state = *static_cast<PilotCallback *>(arg);
  if (count > 0 && state.first) {
    std::cerr << "pilot first_pcm_seconds=" << seconds(state.started) << '\n';
    state.first = false;
  }
  return state.playback ? stream_audio(samples, count, progress, &state.failed)
                        : 1;
}

int main(int argc, char **argv) {
  try {
    if (argc != 4 || !std::getenv("LOCAL_TTS_PILOT_PROVIDER")) {
      throw std::runtime_error("use pilot.py run, not this adapter directly");
    }
    PilotCallback state{Clock::now(), true, false, std::string(argv[2]) == "-"};
    std::string model = argv[1];
    std::string text{std::istreambuf_iterator<char>(std::cin), {}};
    if (text.empty()) {
      throw std::runtime_error("empty input");
    }
    sherpa_onnx::cxx::OfflineTtsConfig config;
    config.model.kokoro.model = model + "/model.onnx";
    config.model.kokoro.voices = model + "/voices.bin";
    config.model.kokoro.tokens = model + "/tokens.txt";
    config.model.kokoro.data_dir = model + "/espeak-ng-data";
    config.model.num_threads = 4;
    config.model.provider = std::getenv("LOCAL_TTS_PILOT_PROVIDER");
    config.model.debug = true;
    auto engine = sherpa_onnx::cxx::OfflineTts::Create(config);
    if (!engine.Get() || engine.SampleRate() != 24000 ||
        engine.NumSpeakers() != 11) {
      throw std::runtime_error("unexpected Kokoro model/API");
    }
    sherpa_onnx::cxx::GenerationConfig generation;
    generation.sid = 1;
    generation.silence_scale = 0.2;
    auto audio = engine.Generate(text, generation, pilot_audio, &state);
    std::cerr << "pilot generation_seconds=" << seconds(state.started)
              << " audio_seconds="
              << audio.samples.size() / static_cast<double>(audio.sample_rate)
              << " playback_backpressure=" << state.playback << '\n';
    if (state.failed || audio.samples.empty()) {
      throw std::runtime_error("generation or stream failed");
    }
    if (!state.playback && !sherpa_onnx::cxx::WriteWave(
                               argv[2], {audio.samples, audio.sample_rate})) {
      throw std::runtime_error("WAV write failed");
    }
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "pilot: " << error.what() << '\n';
    return 1;
  }
}
