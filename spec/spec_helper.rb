require "domoticz"
require "support/spec_helpers"
require "timecop"

LOCAL_OFFSET = DateTime.now.offset

RSpec.configure do |config|
  config.before(:each) do
    Domoticz.reset
  end
end
