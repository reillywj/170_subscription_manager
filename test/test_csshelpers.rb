require 'minitest/autorun'
require_relative '../css_helper_methods'
require 'pry'

class TestCSSHelpers < Minitest::Test
  def test_table
    table = CSSHelpers::HTMLTag.new('table', '', {'class'=>'table data'})
    assert_equal "<table class='table data'></table>", table.to_s
  end

  def test_paragraph
    paragraph = CSSHelpers::HTMLTag.new('p', 'Some text.')
    assert_equal '<p>Some text.</p>', paragraph.to_s
  end

  def test_nested_tag
    strong = CSSHelpers::HTMLTag.new 'strong', 'text'
    paragraph = CSSHelpers::HTMLTag.new('p', "Some #{strong}.")
    assert_equal '<p>Some <strong>text</strong>.</p>', paragraph.to_s
  end

  def test_table_2
    table = CSSHelpers::HTMLTag.new('table')
    thead = CSSHelpers::HTMLTag.new('thead')
    head_tr = CSSHelpers::HTMLTag.new('tr')
    ths = ['Subscriptions', 'Cost']
    ths.each do |text|
      head_tr << CSSHelpers::HTMLTag.new('th', text)
    end
    thead << head_tr
    table << thead

    expected = '<table><thead><tr><th>Subscriptions</th><th>Cost</th></tr></thead></table>'
    assert_equal expected, table.to_s
  end
end