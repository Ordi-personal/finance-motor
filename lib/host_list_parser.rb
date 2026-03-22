# frozen_string_literal: true

require "uri"

module HostListParser
  module_function

  def parse_hosts(*values)
    values.flatten.compact.flat_map { |value| value.to_s.split(",") }
      .map { |entry| normalize_host(entry) }
      .compact
      .uniq
  end

  def first_host(*values)
    parse_hosts(*values).first
  end

  def normalize_host(value)
    candidate = value.to_s.strip
    return nil if candidate.empty?

    uri = URI.parse(candidate.match?(%r{\A[a-z][a-z0-9+\-.]*://}i) ? candidate : "https://#{candidate}")
    host = uri.host.to_s.strip
    host.empty? ? nil : host
  rescue URI::InvalidURIError
    nil
  end
end
