require_relative 'db_connection'

require 'active_support/inflector'

class SQLObject
  def self.columns
    column_names =
    DBConnection.execute2(<<-SQL)
    SELECT
      *
    FROM
      #{table_name}
    SQL
    column_names.first.map! { |column_name| column_name.to_sym }
  end

  def self.finalize!
    columns.each do |column_name|
      define_method("#{column_name}=") do |value|
        attributes[column_name] = value
      end
      define_method("#{column_name}") do
        attributes[column_name]
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    name = self.name.downcase.pluralize
    @table_name ||= name
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
    SELECT
      *
    FROM
      #{table_name}
    SQL

    parse_all(results)
  end

  def self.parse_all(results)
    results.map do |attributes|
      self.new(attributes)
    end
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        id = ?
    SQL

    parse_all(result).first
  end

  def initialize(params = {})
    params.each do |key, value|
      raise "unknown attribute '#{key}'" unless self.class.columns.include?(key.to_sym)
      self.send("#{key}=", value)
    end

    update
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |attr_name| self.send(attr_name) }
  end

  def insert
    col_names = self.class.columns.join(",")
    question_marks = ["?"] * (col_names.count(",") + 1)
    DBConnection.execute(<<-SQL, *attribute_values)
    INSERT INTO
      #{self.class.table_name} (#{col_names})
    VALUES
      (#{question_marks.join(',')})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_names = self.class.columns.map { |col_name| "#{col_name} = ?" }.join(", ")
    DBConnection.execute(<<-SQL, *attribute_values, self.id)
    UPDATE
      #{self.class.table_name}
    SET
      #{col_names}
    WHERE
      id = ?
    SQL

  end

  def save
    self.id.nil? ? insert : update
  end
end
