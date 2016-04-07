require 'minitest/autorun'
require_relative '../html_helper'
require 'pry'

class TestCSSHelpers < Minitest::Test
  def test_table
    table = HTML::Tag.new('table', '', {'class'=>'table data'})
    assert_equal "<table class='table data'></table>", table.to_s
  end

  def test_paragraph
    paragraph = HTML::Tag.new('p', 'Some text.')
    assert_equal '<p>Some text.</p>', paragraph.to_s
  end

  def test_nested_tag
    strong = HTML::Tag.new 'strong', 'text'
    paragraph = HTML::Tag.new('p', "Some #{strong}.")
    assert_equal '<p>Some <strong>text</strong>.</p>', paragraph.to_s
  end

  def test_table_2
    table = HTML::Tag.new('table')
    thead = HTML::Tag.new('thead')
    head_tr = HTML::Tag.new('tr')
    ths = ['Subscriptions', 'Cost']
    ths.each do |text|
      head_tr << HTML::Tag.new('th', text)
    end
    thead << head_tr
    table << thead

    expected = '<table><thead><tr><th>Subscriptions</th><th>Cost</th></tr></thead></table>'
    assert_equal expected, table.to_s
  end
end