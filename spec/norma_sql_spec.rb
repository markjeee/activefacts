#
# ActiveFacts tests: Parse all CQL files and check the generated Ruby.
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#
require 'rubygems'
require 'stringio'
require 'activefacts/vocabulary'
require 'activefacts/support'
require 'activefacts/persistence'
require 'activefacts/input/orm'
require 'activefacts/generate/sql/server'

include ActiveFacts
include ActiveFacts::Metamodel

describe "NORMA Loader with SQL output" do
  # Generate and return the SQL for the given vocabulary
  def sql(vocabulary)
    output = StringIO.new
    @dumper = ActiveFacts::Generate::SQL::SERVER.new(vocabulary.constellation)
    @dumper.generate(output)
    output.rewind
    output.read
  end

  #Dir["examples/norma/Bl*.orm"].each do |orm_file|
  #Dir["examples/norma/Meta*.orm"].each do |orm_file|
  #Dir["examples/norma/[ACG]*.orm"].each do |orm_file|
  Dir["examples/norma/*.orm"].each do |orm_file|
    expected_file = orm_file.sub(%r{examples/norma/(.*).orm\Z}, 'examples/SQL/\1.sql')
    actual_file = orm_file.sub(%r{examples/norma/(.*).orm\Z}, 'spec/actual/\1.sql')
#    next unless File.exists? expected_file

    it "should load ORM and dump valid SQL for #{orm_file}" do
      puts "Reading "+orm_file
      vocabulary = ActiveFacts::Input::ORM.readfile(orm_file)

      # Build and save the actual file:
      sql_text = sql(vocabulary)
      File.open(actual_file, "w") { |f| f.write sql_text }

#      sql_text.should == File.open(expected_file) {|f| f.read }
#      File.delete(actual_file)  # It succeeded, we don't need the file.
    end
  end
end