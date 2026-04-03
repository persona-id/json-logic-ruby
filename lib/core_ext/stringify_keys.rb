class Hash
  def stringify_keys
    transform_keys(&:to_s)
  end
end