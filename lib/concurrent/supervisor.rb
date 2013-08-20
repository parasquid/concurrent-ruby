require 'thread'
require 'functional'

behavior_info(:runnable,
              run: 0,
              stop: 0,
              running?: 0)

module Concurrent

  class Supervisor

    DEFAULT_MONITOR_INTERVAL = 1

    behavior(:runnable)

    WorkerContext = Struct.new(:worker, :thread)

    attr_reader :monitor_interval

    def initialize(opts = {})
      @mutex = Mutex.new
      @workers = []
      @running = false
      @monitor = nil
      @monitor_interval = opts[:monitor] || opts[:monitor_interval] || DEFAULT_MONITOR_INTERVAL
      add_worker(opts[:worker]) unless opts[:worker].nil?
    end

    def run!
      raise StandardError.new('already running') if running?
      @running = true
      @monitor = Thread.new{ monitor }
      Thread.pass
    end

    def run
      raise StandardError.new('already running') if running?
      @running = true
      monitor
    end

    def stop
      return true unless running?
      @running = false
      @mutex.synchronize do
        Thread.kill(@monitor) unless @monitor.nil?
        @monitor = nil

        until @workers.empty?
          context = @workers.pop
          begin
            context.worker.stop
            Thread.pass
          rescue Exception => ex
            # suppress
          ensure
            Thread.kill(context.thread) unless context.thread.nil?
          end
        end
      end
    end

    def running?
      return @running
    end

    def length
      return @workers.length
    end
    alias_method :size, :length

    def add_worker(worker)
      if worker.nil? || running? || ! worker.behaves_as?(:runnable)
        return false
      else
        @mutex.synchronize {
          @workers << WorkerContext.new(worker)
        }
        return true
      end
    end

    private

    def monitor
      loop do
        @mutex.synchronize do
          @workers.each do |context|
            unless context.thread && context.thread.alive?
              context.thread = Thread.new{ context.worker.run }
              context.thread.abort_on_exception = false
            end
          end
        end
        sleep(@monitor_interval)
      end
    end
    end
  end