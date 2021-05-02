require 'sqlite3'
require 'fileutils'
require 'yaml'
require 'logger'

module SqliteActiveRecord 
    class Base
        attr_accessor :tables, :db, :connected :create_tables
        def initialize(file)
            @db_file = file
            @tables = Tables.new(self)
            @create_tables = true
            @connected = false
            @log = nil
        end

        def connect
            puts @db_file
            @db = SQLite3::Database.open @db_file
            @db.results_as_hash = true
            @connected = true
            self.log_info("SQLite3 Connected to file #{@file}", __LINE__)
        rescue SQLite3::Exception => e
            self.log_error "Error on sqllite connection: " + e.message, __LINE__
        end

        def query(sql)
            @connected ? nil : self.connect
            if !@connected then 
                self.log_error "No connection to Sqlite3 database", __LINE__
                return []
            end
            results = @db.query sql
            return results
        rescue SQLite3::Exception => e
            self.log_error "Error on sqllite query: " + e.message, __LINE__
        rescue Exception => e
            self.log_error "Error on sqllite query: " + e.message, __LINE__
        end

        def log_error(message, line = '')
            if @log != nil then
                log_file = '[' + File.basename(__FILE__) + ']'
                line.to_s != '' ? log_line = '[line ' + line.to_s + '] ' : log_line = ''
                @log.error log_file + log_line + message
            end
        end

        def log_info(message, line = '')
            if @log != nil then
                log_file = '[' + File.basename(__FILE__) + ']'
                line.to_s != '' ? log_line = '[line ' + line.to_s + '] ' : log_line = ' '
                @log.info log_file + log_line + message
            end
        end

        def logger(mylogger)
            @log = mylogger
        end
        
        def finalize
            db.close if @db
        end
    end

    class Tables
        def initialize(sqlite)
            @tables = {}
            @sqlite = sqlite
        end
        def method_missing(method_name, *args, &block)
            #puts method_name
            if @tables[method_name].to_s.empty? then
                @tables[method_name] = Table.new(@sqlite, method_name)
            end
            return @tables[method_name]
        end
    end

    class Table
        def initialize(sqlite, table_name)
            @table_name = table_name
            @table_types = []
            @table_keys = []
            @table_sqlite = sqlite
            @table_created = false
        end
        def types(*args) 
            @table_types = args[0]   
        end
        def keys(*args)
            @table_keys = args[0]
        end 
        def create_table
            cols = [] 
            @table_types.each { |name, type| 
                #@table_keys[name].is_nil? ? sql_cols_key = ' ' + @table_keys[name].to_s : sql_cols_key = ''
                sql_cols_key = ''
                cols.push "\"#{name}\" #{type}#{sql_cols_key}"
            }
            sql_cols = cols.join ', '
            sql = 'CREATE TABLE IF NOT EXISTS "' + @table_name.to_s + '" (
                ' + sql_cols + '
                )'
            @table_created = true
            puts sql
            @table_sqlite.query(sql)
        end
        def preset
            self.types(id: 'integer primary key autoincrement')
        end
        def get(**values)
            @table_created ? nil : self.create_table

            where = []
            values.each{|name, value|
            where.push("`#{name}`='#{value}'")
            }
            sql_where = where.join(' AND ')
            sql = "select * from `#{@table_name}` where #{sql_where}" 
            result = @table_sqlite.query(sql)
            if result == '' or !result.is_a? then
                result = {}
            end
            return result 
        end
        def all
            @table_created ? nil : self.create_table
            sql = "select * from `#{@table_name}`" 
            result = @table_sqlite.query(sql)
            if result == '' or !result.is_a? then
                result = {}
            end
            return result             
        end
        def update(**values)
            @table_created ? nil : self.create_table
            @update_where = values
            return Query.new(self,'update_execute')
        end
        def update_execute(upd_values)
            @table_created ? nil : self.create_table
            where = []
            @update_where.each{|name, value|
            where.push("`#{name}`='#{value}'")
            }
            sql_where = where.join(' AND ')
            sql_where.to_s != '' ? sql_where = "where #{sql_where}" : sql_where = ""
            
            upd = []
            upd_values.each{|name, value|
                upd.push("`#{name}`='#{value}'")
            }
            sql_upd = upd.join(', ')

            sql = "update `#{@table_name}` set #{sql_upd} #{sql_where}" 
            @table_sqlite.query(sql)
        end
        def query(sql)
            @table_created ? nil : self.create_table
            sql = sql.gsub('%table%', @table_name.to_s)
            result = @table_sqlite.query(sql)
            if result == '' then
                result = {}
            end
            return result
        end
        def insert(**values)
            @table_created ? nil : self.create_table
            where = []
            @update_where.each{|name, value|
            where.push("`#{name}`='#{value}'")
            }
            sql_columns = '`' + values.keys.join('`, `') + '`'
            sql_values = '"' + values.values.join('", "') + '"'

            sql = "insert into `#{@table_name}` (#{sql_columns}) values (#{sql_values})"
            @table_sqlite.query(sql)
            id = @table_sqlite.db.last_insert_row_id
            return id
        end
        def delete(**values)
            @table_created ? nil : self.create_table
            where = []
            values.each{|name, value|
            where.push("`#{name}`='#{value}'")
            }
            sql_where = where.join(' AND ')
            sql = "delete from `#{@table_name}` where #{sql_where}" 
            @table_sqlite.query(sql)
        end
    end

    class Query
        def initialize(table, table_method)
            @table = table
            @table_method = table_method
            @params = {}
        end
        def save
            @table.send(@table_method,@params)
        end
        def method_missing(name, *args, &block)
            name = name.to_s.split('=')[0]
            @params[name] = args[0]
            return @params[name]
        end
    end
end

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

file = 'bot.db'
sql = SqliteActiveRecord::Base.new(file)
sql.logger(logger)

#sql.tables.media.preset
sql.tables.media.types(id: 'integer primary key autoincrement', media_id: 'text unique', media_type: 'text')
#sql.tables.media.keys(id: 'primary key autoincrement',media_id: 'unique')

#puts tables.media.class

rows = sql.tables.media.get(id: 8)
rows.each{|row|
    puts row['date_add']
}

rows = sql.tables.media.update(id: 8)
rows.date_add = 1
rows.save

rows = sql.tables.media.query("select * from `%table%` where `id`>3")

id = sql.tables.media.insert(media_id: 20, media_type: 'gif', date_add: 3)
puts id

#res = sql.tables.media.delete(id: 10)