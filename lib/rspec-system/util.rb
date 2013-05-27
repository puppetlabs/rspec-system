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
end
