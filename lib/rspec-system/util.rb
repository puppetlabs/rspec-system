# A set of utilities that can be used as a mixin.
module RSpecSystem::Util
  # This is the shellescape method from shellwords from ruby-2.0.0
  #
  # @param str [String] string to escape
  # @return [String] returns escaped string
  def shellescape(str)
    str = str.to_s

    # An empty argument will be skipped, so return empty quotes.
    return "''" if str.empty?

    str = str.dup

    # Treat multibyte characters as is.  It is caller's responsibility
    # to encode the string in the right encoding for the shell
    # environment.
    str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/, "\\\\\\1")

    # A LF cannot be escaped with a backslash because a backslash + LF
    # combo is regarded as line continuation and simply ignored.
    str.gsub!(/\n/, "'\n'")

    return str
  end

  # This is based on the Hash#deep_merge! method from activesupport
  #
  # @param dest_hash [Hash] hash to save merged values into
  # @param other_hash [Hash] hash to merge values from
  # @return [Hash] dest_hash
  def deep_merge!(dest_hash, other_hash)
    other_hash.each_pair do |k,v|
      tv = dest_hash[k]
      dest_hash[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? deep_merge!(tv.dup, v) : v
    end
    dest_hash
  end
end
