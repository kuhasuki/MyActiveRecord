require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @columns ||=  DBConnection.execute2(<<-SQL).first
      SELECT
        *
      FROM
        #{self.table_name}
      LIMIT
        0
    SQL
    @columns.map!(&:to_sym)
  end

  def self.finalize!
    columns.each do |col|
      define_method (col) do
        attributes[col]
      end
      define_method ("#{col}=") do |val|
        attributes[col] = val
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    # @table_name ||= self.to_s.tableize
    return @table_name if @table_name
    @table_name = self.to_s.tableize
    @table_name
  end

  def self.all
    query = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        "#{self.table_name}"
    SQL
    parse_all(query)
  end

  def self.parse_all(results)
    store = []
    results.each do |attr_hash|
      store << self.new(attr_hash)
    end
    store
  end

  def self.find(id)
    target = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        id = ?
    SQL
    target.first ? self.new(target.first) : nil
  end

  def initialize(params = {})
    params.each do |key, val|
      key_sym = key.to_sym
      raise "unknown attribute '#{key}'" unless self.class.columns.include?(key_sym)
      send("#{key}=", val)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    @attributes.values
  end

  def insert
    insert_keys = ""
    attributes.keys.each_with_index do |key, index|
      insert_keys += key.to_s
      insert_keys += ", " unless index == (attributes.keys.length - 1)
    end

    insert_attributes = attribute_values

    questions_string = ""
    attribute_values.length.times do |i|
      questions_string += "?"
      questions_string += ", " unless i == (attribute_values.length - 1)
    end

    DBConnection.execute(<<-SQL, *insert_attributes)
      INSERT INTO
        #{self.class.table_name} (#{insert_keys})
      VALUES
        (#{questions_string});
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update

    cols_string = ""
    self.class.columns.each_with_index do |col, i|
      cols_string += col.to_s + " = ?"
      cols_string += ", " unless i == (self.class.columns.length - 1)
    end

    DBConnection.execute(<<-SQL, *attribute_values)
      UPDATE
        #{self.class.table_name}
      SET
        #{cols_string}
      WHERE
        id = #{self.id}
    SQL

  end

  def save
    id.nil? ? self.insert : self.update
  end
end
