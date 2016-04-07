module CSSHelpers
    # def self.method_missing(method_sym, *arguments, &block)
    #   if method_sym.to_s =~ /^t.*/
    #     "<#{method_sym}>#{yield}</#{method_sym}>"
    #   else
    #     super
    #   end
    # end

  class HTMLTag
    attr_reader :tag, :text
    def initialize(tag, text = '', attributes = {})
      @tag = tag
      @attributes = attributes
      @text = text
    end

    def attributes
      return_string = ''
      @attributes.each do |key, value|
        return_string += " #{key}='#{value}'"
      end
      return_string
    end

    def to_s
      "<#{tag}#{attributes}>#{text}</#{tag}>"
    end

    def <<(other)
      @text += other.to_s
      self
    end
  end
end