$LOAD_PATH.unshift File.expand_path('../', __FILE__)
require 'spec_helper'

require 'builder/builder_log_device'

describe Builder::BuilderLogDevice.new("dummy ws") do
    it 'strip control chars' do
        normal_chars = "blah blah blah"
        actual = subject.strip_control_chars("\x1B[0A\x1B[2K#{normal_chars}\x1B[0B")

        expect(actual).to eq(normal_chars)
    end

    it 'strip color code' do
        normal_chars = "blah blah blah"
        actual = subject.strip_control_chars("\x1B[255;255;255m#{normal_chars}\x1B[0m")

        expect(actual).to eq(normal_chars)
    end
end
