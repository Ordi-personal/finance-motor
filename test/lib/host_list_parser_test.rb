require "test_helper"
require Rails.root.join("lib/host_list_parser")

class HostListParserTest < ActiveSupport::TestCase
  test "parse_hosts normalizes comma separated values" do
    hosts = HostListParser.parse_hosts(
      "https://finance.ordime.app, finance.fluxome.app ,https://finance.ordime.app/path"
    )

    assert_equal [ "finance.ordime.app", "finance.fluxome.app" ], hosts
  end

  test "parse_hosts ignores blanks and invalid values" do
    hosts = HostListParser.parse_hosts(nil, "", "   ", "https://finance.ordime.app", "https://")

    assert_equal [ "finance.ordime.app" ], hosts
  end

  test "first_host returns first normalized host" do
    host = HostListParser.first_host("https://finance.ordime.app", "https://finance.fluxome.app")

    assert_equal "finance.ordime.app", host
  end
end
