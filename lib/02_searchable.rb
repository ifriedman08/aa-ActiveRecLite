require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_line = params.map do |k, v|
      "#{self.table_name}.#{k.to_s} = ?"
    end.join(" AND ")

    cat_info = DBConnection.execute(<<-SQL, params.values)
    SELECT
      #{self.table_name}.*
    FROM
      #{self.table_name}
    WHERE
      #{where_line}
    SQL
    self.parse_all(cat_info)
  end
end

class SQLObject
  extend Searchable
end
