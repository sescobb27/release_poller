defmodule RepoPoller.Poller do
  use GenServer
  require Logger

  alias RepoPoller.{DB, Config}
  alias Domain.Repos.Repo
  alias Domain.Tags.Tag
  alias Domain.Jobs.NewReleaseJob
  alias Domain.Serializers.NewReleaseJobSerializer
  alias RepoPoller.Repository.Service

  defmodule State do
    @enforce_keys [:repo, :pool_id]

    @type adapter :: module()

    @type t :: %__MODULE__{
            repo: Repo.t(),
            adapter: adapter(),
            pool_id: atom(),
            caller: pid()
          }
    defstruct(repo: nil, adapter: nil, pool_id: nil, caller: nil)
  end

  ##############
  # Client API #
  ##############

  def start_link({%{name: repo_name}, _adapter, _pool_id} = args) do
    GenServer.start_link(__MODULE__, args, name: String.to_atom(repo_name))
  end

  def start_link({_caller, %{name: repo_name}, _adapter, _pool_id} = args) do
    GenServer.start_link(__MODULE__, args, name: String.to_atom(repo_name))
  end

  @doc false
  def poll(name) do
    send(name, :poll)
  end

  @doc false
  def state(name) do
    GenServer.call(name, :state)
  end

  ####################
  # Server Callbacks #
  ####################

  @spec init({Repo.t(), State.adapter(), atom()}) :: {:ok, State.t()}
  @impl true
  def init({repo, adapter, pool_id}) do
    state = %State{repo: repo, adapter: adapter, pool_id: pool_id}
    schedule_poll(0)
    {:ok, state}
  end

  @doc false
  @spec init({pid(), Repo.t(), State.adapter(), atom()}) :: {:ok, State.t()}
  @impl true
  def init({caller, repo, adapter, pool_id}) do
    state = %State{
      repo: repo,
      adapter: adapter,
      pool_id: pool_id,
      caller: caller
    }

    {:ok, state}
  end

  @impl true
  def handle_info(
        :poll,
        %{repo: repo, adapter: adapter, caller: caller} = state
      ) do
    repo_name = Repo.uniq_name(repo)
    Logger.info("polling info for repo: #{repo_name}")

    case Service.get_tags(adapter, repo) do
      {:ok, tags} = res ->
        case update_repo_tags(repo, tags, state) do
          {:ok, new_state} ->
            schedule_poll(repo.polling_interval)
            if caller, do: send(caller, res)
            {:noreply, new_state}

          {:error, reason} = error ->
            if caller, do: send(caller, error)
            {:stop, reason, state}
        end

      {:error, :rate_limit, retry} = err ->
        Logger.warn("rate limit reached for repo: #{repo_name} retrying in #{retry} ms")
        schedule_poll(retry)
        if caller, do: send(caller, err)
        {:noreply, state}

      {:error, reason} = err ->
        Logger.error("error polling info for repo: #{repo_name} reason: #{inspect(reason)}")
        schedule_poll(repo.polling_interval)
        if caller, do: send(caller, err)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  #############
  # Internals #
  #############

  @spec schedule_poll(Repo.interval()) :: reference()
  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  # Fetch a repo from the DB, if it doesn't exists, schedule all the fetched tags
  # as jobs, else if it already exists, compare its old tags with the fetched tags
  # and if there are new tags schedule them as jobs
  @spec update_repo_tags(Repo.t(), list(Tag.t()), State.t()) ::
          {:ok, State.t()} | {:error, :out_of_retries}
  defp update_repo_tags(repo, tags, state) do
    repo_name = Repo.uniq_name(repo)

    case DB.get_repo(repo) do
      nil ->
        Logger.info("scheduling jobs for new repo #{repo_name}")
        schedule_jobs(state, repo, tags)

      db_repo ->
        case Tag.new_tags(db_repo.tags, tags) do
          [] ->
            Logger.info("no new tags for #{repo_name}")
            {:ok, state}

          new_tags ->
            Logger.info("scheduling jobs for #{repo_name}")
            schedule_jobs(state, db_repo, new_tags)
        end
    end
  end

  # Try to pick a channel to RabbitMQ and schedule a job up to 5 times
  @spec schedule_jobs(State.t(), Repo.t(), list(Tag.t()), non_neg_integer()) ::
          {:ok, State.t()} | {:error, :out_of_retries}
  defp schedule_jobs(state, repo, new_tags, retries \\ 5)
  defp schedule_jobs(_state, _repo, _new_tags, 0), do: {:error, :out_of_retries}

  defp schedule_jobs(%{pool_id: pool_id} = state, repo, new_tags, retries) do
    BugsBunny.with_channel(pool_id, &do_with_channel(&1, state, repo, new_tags, retries))
  end

  # On channel checkout error retry up to 5 times
  @spec do_with_channel(
          {:ok, AMQP.Channel.t()} | {:error, :disconected | :out_of_channels},
          State.t(),
          Repo.t(),
          list(Tag.t()),
          non_neg_integer()
        ) :: {:ok, State.t()} | {:error, :out_of_retries}
  defp do_with_channel({:error, reason}, state, repo, new_tags, retries) do
    Logger.error("error getting a channel reason: #{reason}")

    Config.get_rabbitmq_reconnection_interval()
    |> :timer.sleep()

    schedule_jobs(state, repo, new_tags, retries - 1)
  end

  # On channel checkout success creates a job per each new repo tag, publish it
  # to RabbitMQ and store the `repo` to the `DB` with all its tags
  defp do_with_channel({:ok, channel}, %{caller: caller} = state, repo, new_tags, _retries) do
    repo_name = Repo.uniq_name(repo)
    jobs = NewReleaseJob.new(repo, new_tags)
    Logger.info("publishing #{length(jobs)} releases for #{repo_name}")

    for job <- jobs do
      job_payload = NewReleaseJobSerializer.serialize!(job)

      case publish_job(channel, job_payload) do
        {:error, reason} ->
          # TODO: handle publish errors e.g maybe remove tag from new_tags so it can be re-scheduled later
          Logger.error("error publishing new release for #{repo_name} reason: #{reason}")
          if caller, do: send(caller, {:job_not_published, job_payload})

          :ok

        :ok ->
          if caller, do: send(caller, {:job_published, job_payload})
          :ok
      end
    end

    :ok =
      Repo.add_tags(repo, new_tags)
      |> DB.save()

    Logger.info("success publishing releases for #{repo_name}")

    {:ok, state}
  end

  @spec publish_job(AMQP.Channel.t(), String.t() | iodata()) :: :ok | AMQP.Basic.error()
  defp publish_job(channel, payload) do
    # pass general config options when publishing new tags e.g :persistent, :mandatory, :immediate etc
    config = Config.get_rabbitmq_config()
    queue = Config.get_rabbitmq_queue()
    exchange = Config.get_rabbitmq_exchange()
    Config.get_rabbitmq_client().publish(channel, exchange, queue, payload, config)
  end
end
