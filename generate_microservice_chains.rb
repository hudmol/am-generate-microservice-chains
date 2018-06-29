#!/usr/bin/env ruby
# coding: utf-8
#
# Generate a Ruby (and Crystal) script corresponding to AM Microservice
# chain/link/task definitions.
#

require 'sequel'
require 'set'

class GenerateMicroserviceChains

  attr_reader :db

  def initialize(watchedDirectoryPath)
    @db = Sequel.connect(:adapter => 'mysql',
                         :user => 'root',
                         :password => '12345',
                         :host => '127.0.0.1',
                         :port => 62001,
                         :database => 'MCP')

    @task_types = load_task_types!

    @methods = []

    watched_directory = db[:WatchedDirectories][:watchedDirectoryPath => watchedDirectoryPath]

    @root_chain = watched_directory[:chain]

    @directory_type = db[:WatchedDirectoriesExpectedTypes][:pk => watched_directory[:expectedType]][:description].to_s

    $unit_variables[@directory_type] ||= {}

    raise "No idea what you're talking about" unless @root_chain
  end

  def call
    toplevel_method = follow_chain(@root_chain)

    [toplevel_method, @methods]
  end

  private

  def load_task_types!
    db[:TaskTypes].map {|row| [row[:pk], row[:description].to_s]}.to_h
  end

  def follow_chain(chain)
    link_pk = db[:MicroServiceChains][:pk => chain][:startingLink] or
      raise "Couldn't get starting link for #{chain}"

    process_link(link_pk)
  end

  # Each link is a new top-level method
  def process_link(link_pk)
    link = db[:MicroServiceChainLinks][:pk => link_pk]
    raise "Lookup failed: #{link_pk}" unless link

    task = db[:TasksConfigs][:pk => link.fetch(:currentTask)]

    microservice_group = link.fetch(:microserviceGroup)
    default_next = link.fetch(:defaultNextChainLink)

    next_by_exit_code = db[:MicroServiceChainLinksExitCodes].filter(:microServiceChainLink => link_pk).map {|row|
      [row[:exitCode], row[:nextMicroServiceChainLink]]
    }.to_h

    task_description = task[:description].to_s

    method = find_method(link_pk)

    return method if method

    method = create_method!(microservice_group, task_description, link_pk, @task_types.fetch(task[:taskType]))

    if @task_types.fetch(task[:taskType]) == 'get user choice to proceed with'
      next_possible_chains = db[:MicroServiceChainChoice].filter(:choiceAvailableAtLink => link_pk)

      next_possible_chains.each do |chain|
        chain_description = db[:MicroServiceChains][:pk => chain[:chainAvailable]][:description].to_s
        next_method = follow_chain(chain[:chainAvailable])

        method.add_block("if get_user_input() == \"#{chain_description}\"") do |m|
          m.prn("return #{next_method.name}()  # #{next_method.link_pk}")
        end
      end

    elsif ['one instance', 'for each file'].include?(@task_types.fetch(task[:taskType]))
      executable = db[:StandardTasksConfigs][:pk => task[:taskTypePKReference]]
      next_by_exit_code.each do |exit_code, next_link_pk|
        method.add_block("if run_client_script(\"#{strescape(executable[:execute].to_s)}, #{strescape(executable[:arguments].to_s)}\") == #{exit_code}") do |m|
          if next_link_pk
            next_method = process_link(next_link_pk)
            m.prn("return #{next_method.name}()  # #{next_method.link_pk}")
          else
            m.prn("# end of the line")
          end
        end
      end

      if default_next
        default_method = process_link(default_next)
        method.prn("return #{default_method.name}()  # #{default_method.link_pk}")
      end

    elsif @task_types.fetch(task[:taskType]) == 'linkTaskManagerSetUnitVariable'
      unit_variable = db[:TasksConfigsSetUnitVariable][:pk => task[:taskTypePKReference]]

      $unit_variables[@directory_type][unit_variable[:variable].to_s] ||= Set.new
      $unit_variables[@directory_type][unit_variable[:variable].to_s] << unit_variable[:microServiceChainLink]

      method.prn("# set variable '#{unit_variable[:variable].to_s}' for type '#{@directory_type}' to transition to '#{unit_variable[:microServiceChainLink]}'")

      if next_by_exit_code[0]
        raise unless (next_by_exit_code.length == 1)
        next_method = process_link(next_by_exit_code[0])
        method.prn("return #{next_method.name}()  # #{next_method.link_pk}")
      else
        method.prn("# missing next step")
      end

    elsif @task_types.fetch(task[:taskType]) == 'linkTaskManagerUnitVariableLinkPull'
      unit_variable = db[:TasksConfigsUnitVariableLinkPull][:pk => task[:taskTypePKReference]]

      if $unit_variables[@directory_type][unit_variable[:variable].to_s] && !$unit_variables[@directory_type][unit_variable[:variable].to_s].empty?
        $unit_variables[@directory_type][unit_variable[:variable].to_s].each do |target_link|
          method.add_block("if read_variable(\"#{unit_variable[:variable].to_s}\", \"#{@directory_type}\") == \"#{target_link}\"") do |m|
            next_method = process_link(target_link)
            m.prn("return #{next_method.name}()  # #{next_method.link_pk}")
          end
        end
      else
        method.prn("# No variable match for '#{unit_variable[:variable].to_s}'.  Going to default")
        next_method = process_link(unit_variable[:defaultMicroServiceChainLink])
        method.prn("return #{next_method.name}()  # #{next_method.link_pk}")
      end

    elsif ['get replacement dic from user choice'].include?(@task_types.fetch(task[:taskType]))
      db[:MicroServiceChoiceReplacementDic].filter(:choiceAvailableAtLink => link_pk).each_with_index do |vars, idx|
        next_link_pk = next_by_exit_code[0]
        method.add_block("if get_user_selection() == \"#{strescape(vars[:description].to_s)}\"") do |m|
          if next_link_pk
            next_method = process_link(next_link_pk)
            m.prn("# set vars #{vars[:replacementDic]}")
            m.prn("return #{next_method.name}()  # #{next_method.link_pk}")
          else
            m.prn("# end of the line")
          end
        end
      end

      if default_next
        default_method = process_link(default_next)
        method.prn("return #{default_method.name}()  # #{default_method.link_pk}")
      else
        method.prn("# end of the line")
      end

    elsif ['Get microservice generated list in stdOut', 'Get user choice from microservice generated list'].include?(@task_types.fetch(task[:taskType]))
      if next_by_exit_code[0]
        raise unless (next_by_exit_code.length == 1)
        next_method = process_link(next_by_exit_code[0])
        method.prn("return #{next_method.name}()  # #{next_method.link_pk}")
      elsif default_next
        default_method = process_link(default_next)
        method.prn("return #{default_method.name}()  # #{default_method.link_pk}")
      else
        method.prn("# end of the line")
      end
    else
      raise "UNKNOWN TASK TYPE: #{@task_types.fetch(task[:taskType])} for #{task[:description].to_s} and link #{link.inspect}"
    end

    method
  end

  def find_method(link_pk)
    for method in @methods
      return method if method.link_pk == link_pk
    end

    nil
  end

  def create_method!(group, task, link_pk, task_type)
    method = Method.new(mint_method_name(group, task, link_pk), link_pk, task_type)
    @methods << method

    method
  end

  def mint_method_name(group, task, link_pk)
    base_name = snake(group) + "__" + snake(task)
    $method_name_registry[base_name] ||= Set.new

    $method_name_registry[base_name] << link_pk

    count = $method_name_registry[base_name].length

    if count == 1
      base_name
    else
      base_name + "_#{count}"
    end
  end

  def snake(s)
    s.strip.split(/ /).map(&:downcase).join('_').gsub(/[-\.\'\/():]/, '_')
  end

  def strescape(s)
    s.gsub(/"/, '\\"')
  end

  class Method
    attr_reader :name, :link_pk

    def initialize(name, link_pk, task_type)
      @name = name
      @link_pk = link_pk
      @task_type = task_type
      @indent = 2
      @body = ""
    end

    def emit
      puts "# #{@link_pk} - #{@task_type}"
      puts "def #{name}"
      puts @body
      puts "end"
    end

    def prn(s)
      @body += (" " * @indent) + s + "\n"
    end

    def add_block(s)
      @body += (" " * @indent) + s + "\n"
      @indent += 2
      yield(self)
      @indent -= 2
      @body += (" " * @indent) + "end\n"
    end
  end
end


puts <<EOF
# Stubs
def get_user_input(*ignored); end
def read_variable(*ignored); end
def run_client_script(*ignored); end
def get_user_selection(*ignored); end
EOF


# Need two passes to make sure we hit all set variable nodes before emitting the
# pull variable ones.
$unit_variables = {}

results = nil
2.times do
  $method_name_registry = {}

  # Run the chains in the order that a simple transfer runs them.
  results = []
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%activeTransfers/standardTransfer').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%workFlowDecisions/quarantineTransfer').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%workFlowDecisions/createTree/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%workFlowDecisions/selectFormatIDToolTransfer/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%workFlowDecisions/extractPackagesChoice/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%workFlowDecisions/examineContentsChoice/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%SIPCreation/completedTransfers/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%system/autoProcessSIP').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%workFlowDecisions/selectFormatIDToolIngest/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%approveNormalization/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%workFlowDecisions/metadataReminder/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%uploadDIP/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%workFlowDecisions/compressionAIPDecisions/').call
  results << GenerateMicroserviceChains.new('%watchDirectoryPath%storeAIP/').call
end

seen = []

results.each do |_, methods|
    methods.each do |m|
      if seen.include?(m.link_pk)
        next
      else
        seen << m.link_pk
      end

      puts "\n"
      m.emit
    end
end

puts "\n\n"

results.each do |toplevel_method, _|
  puts "#{toplevel_method.name}()"
end
