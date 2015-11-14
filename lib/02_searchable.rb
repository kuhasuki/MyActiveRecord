require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable

  def where(params)

    targets = params.values
    where_string = ""
    i = 0

    params.each do |column, value|
      i += 1
      where_string += column.to_s + " = ?"
      where_string += " AND " if i < (params.count)
    end

    result = DBConnection.execute(<<-SQL, *targets)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
      #{where_string}
    SQL

    self.parse_all(result)
  end
end

class SQLObject
  extend Searchable
  # Mixin Searchable here...
end
