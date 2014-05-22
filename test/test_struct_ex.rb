require 'test_helper'
require 'test/unit'
require 'ffi/struct_ex'

class TestStructEx < Test::Unit::TestCase
  def test_bit_fields
    subject_class = Class.new(FFI::StructEx) do
      layout :field_0, bit_fields(:bits_0_2, 3,
                                  :bit_3,    1,
                                  :bit_4,    1,
                                  :bits_5_7, 3,
                                  :bits_8_15, 8),
             :field_1, :uint8,
             :field_2, :uint8,
             :field_3, :uint8
    end

    assert_equal(6, subject_class.size)
    assert_equal(2, subject_class.alignment)
    assert_equal(2, subject_class.offset_of(:field_1))

    subject = subject_class.new

    assert_equal(FFI::StructEx, subject[:field_0].class.superclass)
    assert_equal(2, subject[:field_0].size)

    subject[:field_0] = 0b0110_1001
    assert_equal(0b0110_1001, subject[:field_0].read)
    assert_equal(0b001, subject[:field_0][:bits_0_2])

    subject[:field_0][:bits_0_2] = 0b101
    assert_equal(0b101, subject[:field_0][:bits_0_2])
    assert_equal(0b0110_1101, subject[:field_0].read)

    subject[:field_0] = {bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011}
    assert_equal(0b0110_1001, subject[:field_0].read)
    assert_equal(0b001, subject[:field_0][:bits_0_2])

    assert(subject[:field_0] == {bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011, bits_8_15: 0b0})
    assert(subject[:field_0] == 0b0110_1001)
    assert(subject[:field_0] == '0b0110_1001')

    subject[:field_1] = 1
    subject[:field_2] = 2
    subject[:field_3] = 3
    assert(subject == {field_0: {bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011, bits_8_15: 0b0}, field_1: 1, field_2: 2, field_3: 3})
    assert(subject == 0x0302010069)
    assert(subject == '0x0302010069')
  end

  def test_pure_bit_fields
    subject_class = Class.new(FFI::StructEx) do
      layout :bits_0_2, 3,
             :bit_3,    1,
             :bit_4,    1,
             :bits_5_7, 3
    end

    assert_equal(1, subject_class.size)
    assert_equal(1, subject_class.alignment)

    subject = subject_class.new

    subject[:bits_0_2] = 0b101
    assert_equal(0b101, subject[:bits_0_2])

    subject[:bit_3] = 0b1
    assert_equal(0b1, subject[:bit_3])
    assert_equal(0b101, subject[:bits_0_2])

    subject = subject_class.new(0b0110_1001)
    assert_equal(0b001, subject[:bits_0_2])
    assert_equal(0b1, subject[:bit_3])
    assert_equal(0b0, subject[:bit_4])
    assert_equal(0b011, subject[:bits_5_7])

    subject = subject_class.new(bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011)
    assert_equal(0b001, subject[:bits_0_2])
    assert_equal(0b1, subject[:bit_3])
    assert_equal(0b0, subject[:bit_4])
    assert_equal(0b011, subject[:bits_5_7])
    assert_equal(0b0110_1001, subject.read)
  end

  def test_interpreted_bit_fields
    subject_class = Class.new(FFI::StructEx) do
      layout :bits_0_2, 3, {'all_1' => 0b111, 'all_0' => 0b000},
             :bit_3,    1, {'yes' => 0b1, 'no' => 0b0},
             :bit_4,    1,
             :bits_5_7, 3
    end

    subject = subject_class.new(bits_0_2: 'all_1', bit_3: 'yes')
    assert_equal(0b111, subject[:bits_0_2])
    assert_equal(0b1, subject[:bit_3])
    assert_equal(0b0, subject[:bit_4])
    assert_equal(0b0, subject[:bits_5_7])

    subject[:bits_0_2] = 'all_0'
    assert_equal(0b000, subject[:bits_0_2])

    subject[:bits_0_2] = 0b010
    assert_equal(0b010, subject[:bits_0_2])

    subject[:bit_3] = 'no'
    assert_equal(0b0, subject[:bit_3])

    subject[:bit_3] = 1
    assert_equal(0b1, subject[:bit_3])
  end

  def test_equality
    subject_class = Class.new(FFI::StructEx) do
      layout :field_0, bit_fields(:bits_0_2, 3,
                                  :bit_3,    1,
                                  :bit_4,    1,
                                  :bits_5_7, 3),
             :field_1, :uint8
    end

    subject = subject_class.new({field_0: {bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011}, field_1: 0x1})

    assert_equal(FFI::StructEx, subject[:field_0].class.superclass)
    assert_equal(1, subject[:field_0].size)
    assert(subject[:field_0] == 0b0110_1001)
    assert(subject[:field_1] == subject.map_field_value(:field_1, '0x1'))
  end

  def test_descriptors
    subject_class = Class.new(FFI::StructEx) do
      layout :field_0, :uint8, {'all_1' => 0xff, 'all_0' => 0x00},
             :field_1, :uint8, {3 => 1}
    end

    assert_equal(2, subject_class.size)
    assert_equal(1, subject_class.alignment)
    assert_equal(1, subject_class.offset_of(:field_1))

    subject = subject_class.new(field_0: 'all_1', field_1: 0x12)

    assert_equal(0xff, subject[:field_0])
    assert_equal(0x12, subject[:field_1])

    subject[:field_0] = 'all_0'
    assert_equal(0x00, subject[:field_0])

    subject[:field_0] = 0x12
    assert_equal(0x12, subject[:field_0])

    subject[:field_1] = 3
    assert_equal(0x1, subject[:field_1])
  end

  def test_initialized_memory_should_be_zero
    subject_class = Class.new(FFI::StructEx) do
      layout :field_0, bit_fields(:bits_0_2, 3,
                                  :bit_3,    1,
                                  :bit_4,    1,
                                  :bits_5_7, 3),
             :field_1, :uint8
    end

    subject = subject_class.new

    assert_equal(0x00, subject[:field_0])
    assert_equal(0x00, subject[:field_1])
  end

  # def test_sizeof
    # subject_class = Class.new(FFI::StructEx) do
      # layout :field_0, 2,
             # :field_1, 31
    # end
#
    # assert_equal(8, subject_class.size)
  # end
end