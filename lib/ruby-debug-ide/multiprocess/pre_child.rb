module Debugger
  module MultiProcess
    class << self
      def pre_child(options = nil)
        require 'socket'
        require 'ostruct'

        host = ENV['DEBUGGER_HOST']
        child_process_ports = if ENV['DEBUGGER_CHILD_PROCESS_PORTS']
                                ENV['DEBUGGER_CHILD_PROCESS_PORTS'].split(/-/)
                              else
                                nil
                              end
        port = find_free_port(host, child_process_ports)

        options ||= OpenStruct.new(
            'frame_bind'  => false,
            'host'        => host,
            'load_mode'   => false,
            'port'        => port,
            'stop'        => false,
            'tracing'     => false,
            'int_handler' => true,
            'cli_debug'   => (ENV['DEBUGGER_CLI_DEBUG'] == 'true'),
            'notify_dispatcher' => true,
            'evaluation_timeout' => 10,
            'trace_to_s' => false,
            'debugger_memory_limit' => 10,
            'inspect_time_limit' => 100
        )

        if(options.ignore_port)
          options.port = find_free_port(options.host, child_process_ports)
          options.notify_dispatcher = true
        end

        start_debugger(options)
      end

      def start_debugger(options)
        if Debugger.started?
          # we're in forked child, only need to restart control thread
          Debugger.breakpoints.clear
          Debugger.control_thread = nil
          Debugger.start_control(options.host, options.port, options.notify_dispatcher)
        end

        if options.int_handler
          # install interruption handler
          trap('INT') { Debugger.interrupt_last }
        end

        # set options
        Debugger.keep_frame_binding = options.frame_bind
        Debugger.tracing = options.tracing
        Debugger.evaluation_timeout = options.evaluation_timeout
        Debugger.trace_to_s = options.trace_to_s
        Debugger.debugger_memory_limit = options.debugger_memory_limit
        Debugger.inspect_time_limit = options.inspect_time_limit
        Debugger.cli_debug = options.cli_debug
        Debugger.prepare_debugger(options)
      end


      def find_free_port(host, child_process_ports)
        if child_process_ports.nil?
          server = TCPServer.open(host, 0)
          port   = server.addr[1]
          server.close
          port
        else
          ports = Range.new(child_process_ports[0], child_process_ports[1]).to_a
          raise "Could not find open port in range #{child_process_ports[0]} to #{child_process_ports[1]}" if ports.empty?
          final_port = nil
          ports.each do |port|
            begin
              server = TCPServer.open(host, port)
              server.close
              final_port = port
              break
            rescue
              next
            end
          end
          final_port
        end
      end
    end

  end
end