# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Cross-platform data validation test suite
# This configuration tests data exchange compatibility across different platforms

# Data validation configuration is defined in terraform.tf

locals {
  # Test data covering various edge cases and platform-specific scenarios
  platform_test_data = {
    # Unicode and internationalization
    unicode_strings = {
      ascii = "Hello World 123 !@#$%^&*()"
      chinese_simplified = "你好世界"
      chinese_traditional = "你好世界"
      japanese_hiragana = "こんにちはせかい"
      japanese_katakana = "コンニチハセカイ"
      korean = "안녕하세요 세계"
      arabic = "مرحبا بالعالم"
      hebrew = "שלום עולם"
      russian = "Привет мир"
      emoji_basic = "🌍🌎🌏"
      emoji_complex = "👨‍💻👩‍💻🚀✨🎉"
      mixed_scripts = "Hello 世界 🌍 Привет мир"
    }
    
    # Special characters and escape sequences
    special_characters = {
      quotes = "\"double quotes\" and 'single quotes'"
      backslashes = "C:\\Windows\\System32\\file.txt"
      newlines = "line1\nline2\nline3"
      carriage_returns = "line1\r\nline2\r\nline3"
      tabs = "column1\tcolumn2\tcolumn3"
      mixed_whitespace = " \t\n\r mixed whitespace \t\n\r "
      null_chars = "before\u0000after"
      control_chars = "\u0001\u0002\u0003\u001F"
      unicode_escapes = "\\u0048\\u0065\\u006C\\u006C\\u006F"
    }
    
    # Numeric precision and edge cases
    numeric_data = {
      integers = {
        zero = 0
        positive_small = 42
        positive_large = 9223372036854775807
        negative_small = -42
        negative_large = -9223372036854775808
      }
      floats = {
        zero = 0.0
        positive_small = 3.14159
        positive_large = 1.7976931348623157e+308
        negative_small = -3.14159
        negative_large = -1.7976931348623157e+308
        scientific_notation = 1.23e-10
        very_precise = 0.123456789012345
      }
      edge_cases = {
        infinity = "infinity"
        negative_infinity = "-infinity"
        not_a_number = "NaN"
      }
    }
    
    # Complex nested structures
    nested_data = {
      level1 = {
        level2 = {
          level3 = {
            level4 = {
              level5 = {
                deep_value = "nested 5 levels deep"
                array_in_deep = [1, 2, 3, "deep array"]
              }
            }
            level4_array = [
              { name = "item1", value = 100 },
              { name = "item2", value = 200 }
            ]
          }
          level3_mixed = {
            string = "mixed content"
            number = 42
            boolean = true
            null_value = null
            empty_array = []
            empty_object = {}
          }
        }
      }
    }
    
    # Array and object variations
    data_structures = {
      empty_array = []
      simple_array = [1, 2, 3, 4, 5]
      mixed_array = [1, "two", true, null, 4.5]
      nested_arrays = [[1, 2], [3, 4], [5, 6]]
      array_of_objects = [
        { id = 1, name = "first", active = true },
        { id = 2, name = "second", active = false },
        { id = 3, name = "third", active = true }
      ]
      empty_object = {}
      simple_object = { key1 = "value1", key2 = "value2" }
      mixed_object = {
        string_val = "text"
        number_val = 123
        boolean_val = true
        null_val = null
        array_val = [1, 2, 3]
        object_val = { nested = "value" }
      }
    }
    
    # Platform-specific path handling
    path_data = {
      unix_absolute = "/home/user/documents/file.json"
      unix_relative = "./config/settings.json"
      unix_hidden = "/home/user/.config/app/config.json"
      windows_absolute = "C:\\Users\\User\\Documents\\file.json"
      windows_unc = "\\\\server\\share\\file.json"
      windows_relative = ".\\config\\settings.json"
      mixed_separators = "C:/Users/User\\Documents/file.json"
    }
    
    # Date and time formats
    datetime_data = {
      iso8601_basic = "2024-01-01T00:00:00Z"
      iso8601_with_timezone = "2024-01-01T12:30:45.123+05:30"
      rfc3339 = "2024-01-01T00:00:00.000Z"
      unix_timestamp = 1704067200
      human_readable = "January 1, 2024 12:00 PM UTC"
      various_formats = [
        "2024-01-01",
        "01/01/2024",
        "1-Jan-2024",
        "2024-001", # Julian date
        "20240101T120000Z"
      ]
    }
  }
}

# Test outputs for all indentation formats
output "unicode_data_2spaces" {
  description = "Unicode test data with 2-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.unicode_strings),
    "2spaces"
  )
}

output "unicode_data_4spaces" {
  description = "Unicode test data with 4-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.unicode_strings),
    "4spaces"
  )
}

output "unicode_data_tabs" {
  description = "Unicode test data with tab indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.unicode_strings),
    "tab"
  )
}

output "special_chars_2spaces" {
  description = "Special characters test with 2-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.special_characters),
    "2spaces"
  )
}

output "special_chars_4spaces" {
  description = "Special characters test with 4-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.special_characters),
    "4spaces"
  )
}

output "special_chars_tabs" {
  description = "Special characters test with tab indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.special_characters),
    "tab"
  )
}

output "numeric_precision_2spaces" {
  description = "Numeric precision test with 2-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.numeric_data),
    "2spaces"
  )
}

output "nested_structures_4spaces" {
  description = "Complex nested structures with 4-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.nested_data),
    "4spaces"
  )
}

output "data_structures_tabs" {
  description = "Various data structures with tab indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.data_structures),
    "tab"
  )
}

output "platform_paths_2spaces" {
  description = "Platform-specific path handling with 2-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.path_data),
    "2spaces"
  )
}

output "datetime_formats_4spaces" {
  description = "Date and time format handling with 4-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data.datetime_data),
    "4spaces"
  )
}

# Comprehensive test combining all data types
output "comprehensive_test_2spaces" {
  description = "Comprehensive test data with 2-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data),
    "2spaces"
  )
}

output "comprehensive_test_4spaces" {
  description = "Comprehensive test data with 4-space indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data),
    "4spaces"
  )
}

output "comprehensive_test_tabs" {
  description = "Comprehensive test data with tab indentation"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.platform_test_data),
    "tab"
  )
}

# Platform metadata for validation
output "test_metadata" {
  description = "Test execution metadata"
  value = {
    terraform_version = "unknown" # Will be populated by test runner
    platform = "unknown"          # Will be populated by test runner
    timestamp = timestamp()
    test_suite = "cross-platform-data-validation"
    total_outputs = 13
    indentation_formats = ["2spaces", "4spaces", "tabs"]
    data_categories = [
      "unicode_strings",
      "special_characters", 
      "numeric_data",
      "nested_data",
      "data_structures",
      "path_data",
      "datetime_data"
    ]
  }
}