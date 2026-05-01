require 'backport_dig' if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3')

class Hash
  def deep_fetch(key, default = nil)
    keys = key.to_s.split('.')
    value = keys.reduce(self) do |node, k|
      break default if node.nil?
      node.is_a?(Array) ? node[k.to_i] : node[k]
    end
    value.nil? ? default : value  # value can be false (Boolean)
  rescue
    default
  end
end

class Array
  def deep_fetch(key, default = nil)
    keys = key.to_s.split('.')
    value = keys.reduce(self) do |node, k|
      break default if node.nil?
      node.is_a?(Array) ? node[k.to_i] : node[k]
    end
    value.nil? ? default : value  # value can be false (Boolean)
  rescue
    default
  end
end
