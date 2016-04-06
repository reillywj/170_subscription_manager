class CSSHelpers
  def self.method_missing(method_sym, *arguments, &block)
    if method_sym.to_s =~ /^t.*/
      "<#{method_sym}>#{yield}</#{method_sym}>"
    else
      super
    end
  end
end