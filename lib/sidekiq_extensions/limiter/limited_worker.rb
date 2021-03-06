module SidekiqExtensions
	class Limiter
		class LimitedWorker

			PER_HOST_KEY = :per_host
			PER_PROCESS_KEY = :per_process
			PER_QUEUE_KEY = :per_queue
			PER_REDIS_KEY = :per_redis
			PRIORITIZED_COUNT_SCOPES = [PER_REDIS_KEY, PER_QUEUE_KEY, PER_HOST_KEY, PER_PROCESS_KEY]

			attr_reader :message, :worker

			def capacity_available?(connection, skip_purge_and_retry = false)
				availability = prioritized_limits.zip(scopes_counts(connection)).map{|counts| counts.inject(:-)}.none?{|count_diff| count_diff <= 0}
				return availability if availability || skip_purge_and_retry
				purge_stale_workers(connection)
				capacity_available?(connection, true)
			end



			def fetch_option(option_name, default = nil)
				@limiter_options ||= Sidekiq.options.fetch(:limiter, {})
				[options.fetch(option_name.to_s, nil), @limiter_options.fetch(option_name.to_sym, nil), default].compact.each do |option|
					return option.respond_to?(:call) ? option.call(@message) : option
				end
			end


			def initialize(worker, message)
				@message = message
				@worker = worker
			end


			def key
				return @key ||= SidekiqExtensions.namespaceify(
					Sidekiq.options[:namespace],
					:sidekiq_extensions,
					:limiter,
					fetch_option(:key, worker.class.to_s.underscore.gsub('/', ':'))
				)
			end


			def limited_scopes
				return @limited_scopes ||= options.keys.map(&:to_sym) & PRIORITIZED_COUNT_SCOPES
			end


			def max_retries
				return fetch_option(:retry, MAX_RETRIES) || 0
			end


			def options
				return @options ||= (worker.class.get_sidekiq_options['limits'] || {}).stringify_keys
			end


			def prioritized_limits
				return @prioritized_limits ||= limited_scopes.map{|scope| options[scope.to_s]}
			end


			def purge_stale_workers(connection)
				connection.multi do
					scopes_keys.each do |scope_key|
						connection.sinterstore(scope_key, scope_key, 'workers')
					end
				end
			end


			def retry_delay(retry_count)
				# By default will retry 10 times over the course of about 5 hours
				default = lambda{|message| (retry_count ** 4) + 15 + (rand(50) * (retry_count + 1))}
				return fetch_option(:retry_delay, default)
			end


			def scopes_counts(connection)
				current_counts = connection.multi do
					scopes_keys.map{|key| connection.scard(key)}
				end
				return current_counts.map(&:to_i)
			end


			def scopes_keys
				return @scopes_keys ||= {
					PER_REDIS_KEY => SidekiqExtensions.namespaceify(key, PER_REDIS_KEY.to_s),
					PER_QUEUE_KEY => SidekiqExtensions.namespaceify(key, PER_QUEUE_KEY, message['queue']),
					PER_HOST_KEY => SidekiqExtensions.namespaceify(key, PER_HOST_KEY, Socket.gethostname),
					PER_PROCESS_KEY => SidekiqExtensions.namespaceify(key, PER_PROCESS_KEY, Socket.gethostname, Process.pid),
				}.values_at(*limited_scopes)
			end


			def update_scopes(action, existing_connection = nil)
				adjuster = lambda do |connection|
					connection.multi do
						scopes_keys.each do |scope_key|
							connection.send((action == :register ? 'sadd' : 'srem'), scope_key, SidekiqExtensions.thread_identity)
						end
					end
				end
				existing_connection ? adjuster.call(existing_connection) : Sidekiq.redis(&adjuster)
			end

		end
	end
end
