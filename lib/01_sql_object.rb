require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'


# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    col_data = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
      SQL
    col_data.first.map {|col| col.to_sym}
  end

  def self.finalize!
    columns.each do |col|
      define_method(col) do
        self.attributes[col.to_sym]
      end

      define_method("#{col}=") do |new_val|
        self.attributes[col.to_sym] = new_val
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= "#{self}".tableize
  end

  def self.all
    rows = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      SQL

    self.parse_all(rows)
  end

  def self.parse_all(results)
    results.map do |attr_hash|
      self.new(attr_hash)
    end
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL, id)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = ?
      SQL
    if result.empty?
      nil
    else
      self.new(result.first)
    end
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      self.class.finalize!
      unless self.class.columns.include?(attr_name.to_sym)
        raise "unknown attribute '#{attr_name}'"
      end

      send("#{attr_name}=", value)

    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map do |attr|
      self.send(attr)
    end
  end

  def insert
    col_names = self.class.columns.drop(1).join(", ")
    attr_vals = self.attribute_values.compact
    n = self.attribute_values.length - 1
    table = self.class.table_name
    qmarks = (["?"] * n).join(", ")

    DBConnection.execute(<<-SQL, attr_vals)
      INSERT INTO
        #{table} (#{col_names})
      VALUES
        (#{qmarks})
      SQL
    self.id = DBConnection.last_insert_row_id

  end

  def update
    attr_vals = self.attribute_values.compact
    col_names = self.class.columns.map do |attr|
      "#{attr} = ?"
    end.join(", ")
    table = self.class.table_name
    id = self.id

    DBConnection.execute(<<-SQL, attr_vals, id)
      UPDATE
        #{table}
      SET
      #{col_names}
      WHERE
        #{table}.id = ?
      SQL
  end

  def save
    if self.id.nil?
      self.insert
    else
      self.update
    end
  end
end
