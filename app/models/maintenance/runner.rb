module Maintenance
  # Runs a task and keeps the run (MaintenanceRun). A preview (or a check)
  # only reads; an apply does it all or nothing; a revert undoes an apply.
  # A failure is kept as a failed run with its error, never raised.
  class Runner
    def self.run(task, params: {}, apply: false, user: nil)
      new(task, user:).run(params:, apply:)
    end

    def self.revert(run, user: nil)
      new(run.task, user:).revert(run)
    end

    def initialize(task, user:)
      @task = task
      @user = user
    end

    def run(params:, apply:)
      apply &&= @task.changes_data?
      instance = @task.new(params)
      record(mode: apply ? "apply" : "preview", params: instance.params) do
        changes = {}
        sections = nil
        if apply
          ActiveRecord::Base.transaction do
            changes = instance.apply!
            sections = instance.sections_after_apply(changes)
          end
        else
          sections = instance.sections
        end
        [ sections, changes ]
      end
    end

    def revert(run)
      return unless run.revertible?

      record(mode: "revert", params: { "run_id" => run.id }, reverted_run: run) do
        count = nil
        ActiveRecord::Base.transaction do
          run.lock!
          raise ActiveRecord::Rollback if run.reverted?

          count = @task.revert!(run.changes_made)
          run.update!(reverted_at: Time.current)
        end
        [ [ Section.new(title: I18n.t("maintenance.revert.title"), status: "ok",
                        lines: [ I18n.t("maintenance.revert.done", count: count.to_i) ]) ], {} ]
      end
    end

    private
      def record(mode:, params:, reverted_run: nil)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        run = MaintenanceRun.new(task_key: @task.key, mode:, params:, user: @user, reverted_run:,
                                 request_id: Current.request_id)
        begin
          sections, changes = yield
          run.assign_attributes(sections: sections.map(&:to_h), changes_made: changes,
                                status: Maintenance.worst(sections.map(&:status)))
        rescue StandardError => error
          Rails.error.report(error, handled: true, context: { maintenance_task: @task.key, mode: })
          run.assign_attributes(status: "failed", sections: [], changes_made: {}, error: "#{error.class}: #{error.message}".first(2_000))
        end
        run.duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        run.save!
        run
      end
  end
end
