require 'minitest/autorun'
require 'minitest/pride'

require 'json'
require 'open-uri'

require 'json_logic'

class JSONLogicTest < Minitest::Test
  test_suite_url = 'http://jsonlogic.com/tests.json'
  tests = JSON.parse(open(test_suite_url).read)
  count = 1
  tests.each do |pattern|
    next unless pattern.is_a?(Array)
    define_method("test_#{count}") do
      result = JSONLogic.apply(pattern[0], pattern[1])
      msg = "#{pattern[0].to_json} (data: #{pattern[1].to_json})"

      if pattern[2].nil?
        assert_nil(result, msg)
      else
        assert_equal(pattern[2], result, msg)
      end
    end
    count += 1
  end

  def test_filter
    filter = JSON.parse(%Q|{">": [{"var": "id"}, 1]}|)
    data = JSON.parse(%Q|[{"id": 1},{"id": 2}]|)
    assert_equal([{'id' => 2}], JSONLogic.filter(filter, data))
  end

  def test_symbol_operation
    logic = {'==': [{var: "id"}, 1]}
    data = JSON.parse(%Q|{"id": 1}|)
    assert_equal(true, JSONLogic.apply(logic, data))
  end

  def test_false_value
    logic = {'==': [{var: "flag"}, false]}
    data = JSON.parse(%Q|{"flag": false}|)
    assert_equal(true, JSONLogic.apply(logic, data))
  end

  def test_add_operation
    new_operation = ->(v, d) { v.map { |x| x + 5 } }
    JSONLogic.add_operation('fives', new_operation)
    rules = JSON.parse(%Q|{"fives": {"var": "num"}}|)
    data = JSON.parse(%Q|{"num": 1}|)
    assert_equal([6], JSONLogic.apply(rules, data))
  end

  def test_exponent_operation
    exp = JSON.parse(%Q|{"^": [{"var": "num"}, 3]}|)
    data1 = JSON.parse(%Q|{"num": 2}|)
    data2 = JSON.parse(%Q|{"num": 3}|)
    data3 = JSON.parse(%Q|{"num": 4}|)

    assert_equal(8, JSONLogic.apply(exp, data1).to_i)
    assert_equal(27, JSONLogic.apply(exp, data2).to_i)
    assert_equal(64, JSONLogic.apply(exp, data3).to_i)
  end

  def test_array_with_logic
    assert_equal [1, 2, 3], JSONLogic.apply([1, {"var" => "x"}, 3], {"x" => 2})

    assert_equal [42], JSONLogic.apply(
      {
        "if" => [
          {"var" => "x"},
          [{"var" => "y"}],
          99
        ]
      },
      { "x" => true, "y" => 42}
    )
  end

  def test_in_with_variable
    assert_equal true, JSONLogic.apply(
      {
        "in" => [
          {"var" => "x"},
          {"var" => "x"}
        ]
      },
      { "x" => "foo"}
    )

    assert_equal false, JSONLogic.apply(
      {
        "in" => [
          {"var" => "x"},
          {"var" => "y"},
        ]
      },
      { "x" => "foo", "y" => "bar" }
    )
  end

  def test_uses_data
    assert_equal ["x", "y"], JSONLogic.uses_data(
      {
        "in" => [
          {"var" => "x"},
          {"var" => "y"},
        ]
      }
    )
  end

  def test_uses_data_array
    assert_equal ["a", "x", "y", "z"], JSONLogic.uses_data(
      {
        "in" => [
          [ { "var" => "a" }, { "var" => "x" } ],
          [ { "var" => "y" }, { "var" => "z" } ]
        ]
      }
    )
  end

  def test_uses_data_complex
    assert_equal ["temp", "pie.filling"], JSONLogic.uses_data(
      {
        "and" => [
          {"<" => [ { "var" => "temp" }, 110 ]},
          {"==" => [ { "var" => "pie.filling" }, "apple" ]}
        ]
      }
    )
  end

  def test_uses_data_missing
    vars = JSONLogic.uses_data(
      {
        "in" => [
          {"var" => "x"},
          {"var" => "y"},
        ]
      }
    )

    provided_data_missing_y = {
      x: 3,
    }

    provided_data_missing_x = {
      y: 4,
    }

    assert_equal ["y"], JSONLogic.apply({"missing": [vars]}, provided_data_missing_y)
    assert_equal ["x"], JSONLogic.apply({"missing": [vars]}, provided_data_missing_x)
  end

  def test_deep_fetch_array_traversal
    data = { "addresses" => [{ "city" => "Oakland" }, { "city" => "SF" }] }
    assert_equal "Oakland", data.deep_fetch("addresses.0.city")
    assert_equal "SF",      data.deep_fetch("addresses.1.city")
  end

  def test_deep_fetch_array_out_of_bounds_returns_default
    data = { "addresses" => [{ "city" => "Oakland" }] }
    assert_nil data.deep_fetch("addresses.9.city")
    assert_equal "fallback", data.deep_fetch("addresses.9.city", "fallback")
  end

  def test_deep_fetch_missing_key_returns_default
    data = { "user" => { "name" => "Alice" } }
    assert_nil data.deep_fetch("user.age")
    assert_equal "unknown", data.deep_fetch("user.age", "unknown")
  end

  def test_deep_fetch_preserves_false_value
    data = { "flags" => [{ "enabled" => false }] }
    assert_equal false, data.deep_fetch("flags.0.enabled")
  end

  def test_var_with_array_traversal
    logic = { "var" => "addresses.0.city" }
    data  = { "addresses" => [{ "city" => "Oakland" }] }
    assert_equal "Oakland", JSONLogic.apply(logic, data)
  end

  def test_var_with_non_first_array_element
    logic = { "var" => "addresses.2.city" }
    data  = { "addresses" => [{ "city" => "Oakland" }, { "city" => "SF" }, { "city" => "Los Angeles" }] }
    assert_equal "Los Angeles", JSONLogic.apply(logic, data)
  end

  def test_var_with_array_data_containing_hashes
    logic = { "var" => "1.city" }
    data  = [{ "city" => "Oakland" }, { "city" => "SF" }]
    assert_equal "SF", JSONLogic.apply(logic, data)
  end

  def test_var_with_array_data_deeper_nesting
    logic = { "var" => "0.address.city" }
    data  = [{ "address" => { "city" => "Oakland" } }]
    assert_equal "Oakland", JSONLogic.apply(logic, data)
  end

  def test_var_with_array_data_missing_key_returns_nil
    logic = { "var" => "0.missing" }
    data  = [{ "city" => "Oakland" }]
    assert_nil JSONLogic.apply(logic, data)
  end

end
