class Throttle < Formula
  desc "Native macOS CLI for simulating constrained network conditions"
  homepage "https://github.com/odd-theory/throttle"
  url "https://github.com/odd-theory/throttle/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "eeea02a05cee3ad643780c3526d18a6c87c58e3d43422a6fbeef32b5e530dd45"
  license "MIT"

  depends_on xcode: ["16.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/throttle"
  end

  test do
    assert_match "WiFi", shell_output("#{bin}/throttle list")
  end
end
