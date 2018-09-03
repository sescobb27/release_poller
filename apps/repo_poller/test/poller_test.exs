defmodule RepoPoller.PollerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias RepoPoller.Poller
  alias RepoPoller.Repository.GithubFake
  alias Domain.Repos.Repo
  alias Domain.Tags.Tag
  alias RepoPoller.DB

  alias BugsBunny.FakeRabbitMQ
  alias BugsBunny.Worker.RabbitConnection

  setup do
    DB.clear()

    on_exit(fn ->
      DB.clear()
    end)
  end

  setup do
    n = :rand.uniform(100)
    pool_id = String.to_atom("test_pool#{n}")
    caller = self()

    rabbitmq_config = [
      channels: 1,
      queue: "new_releases.queue",
      exchange: "",
      client: FakeRabbitMQ,
      caller: caller
    ]

    rabbitmq_conn_pool = [
      :rabbitmq_conn_pool,
      pool_id: pool_id,
      name: {:local, pool_id},
      worker_module: RabbitConnection,
      size: 1,
      max_overflow: 0
    ]

    Application.put_env(:repo_poller, :rabbitmq_config, rabbitmq_config)

    start_supervised!(%{
      id: BugsBunny.PoolSupervisorTest,
      start:
        {BugsBunny.PoolSupervisor, :start_link,
         [
           [rabbitmq_config: rabbitmq_config, rabbitmq_conn_pool: rabbitmq_conn_pool],
           BugsBunny.PoolSupervisorTest
         ]},
      type: :supervisor
    })

    {:ok, pool_id: pool_id}
  end

  test "gets tags and re-schedule poll", %{pool_id: pool_id} do
    repo = Repo.new("https://github.com/elixir-lang/elixir")
    pid = start_supervised!({Poller, {self(), repo, GithubFake, pool_id, 50}})
    Poller.poll(pid)
    assert_receive {:ok, tags}, 1000
    assert_receive {:ok, ^tags}
  end

  test "gets repo tags and store them", %{pool_id: pool_id} do
    repo = Repo.new("https://github.com/elixir-lang/elixir")
    pid = start_supervised!({Poller, {self(), repo, GithubFake, pool_id, 5_000}})
    Poller.poll(pid)
    assert_receive {:ok, _tags}, 1000
    tags = DB.get_tags(repo)
    refute Enum.empty?(tags)
    %{repo: %{tags: state_tags}} = Poller.state(pid)
    assert state_tags == tags
  end

  test "gets repo tags and update them", %{pool_id: pool_id} do
    repo =
      Repo.new("https://github.com/elixir-lang/elixir")
      |> Repo.add_tags([
        %Tag{
          commit: %{
            sha: "1ec9d1d7bdd01665deb3607ba6beb8bcd524b85d",
            url:
              "https://api.github.com/repos/elixir-lang/elixir/commits/1ec9d1d7bdd01665deb3607ba6beb8bcd524b85d"
          },
          name: "v1.6.6",
          node_id: "MDM6UmVmMTIzNDcxNDp2MS42LjY=",
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.6.6",
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.6.6"
        },
        %Tag{
          commit: %{
            sha: "a9f1be07ca1a939739bd013f100686c8cf81432a",
            url:
              "https://api.github.com/repos/elixir-lang/elixir/commits/a9f1be07ca1a939739bd013f100686c8cf81432a"
          },
          name: "v1.6.5",
          node_id: "MDM6UmVmMTIzNDcxNDp2MS42LjU=",
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.6.5",
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.6.5"
        },
        %Tag{
          commit: %{
            sha: "c107a2fe2623d11d132cdfeefbb7370abd44f85c",
            url:
              "https://api.github.com/repos/elixir-lang/elixir/commits/c107a2fe2623d11d132cdfeefbb7370abd44f85c"
          },
          name: "v1.6.4",
          node_id: "MDM6UmVmMTIzNDcxNDp2MS42LjQ=",
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.6.4",
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.6.4"
        },
        %Tag{
          commit: %{
            sha: "45c7f828ef7cb29647d4ac999761ed4e2ff0dc08",
            url:
              "https://api.github.com/repos/elixir-lang/elixir/commits/45c7f828ef7cb29647d4ac999761ed4e2ff0dc08"
          },
          name: "v1.6.3",
          node_id: "MDM6UmVmMTIzNDcxNDp2MS42LjM=",
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.6.3",
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.6.3"
        },
        %Tag{
          commit: %{
            sha: "c2a9c93f023c0c00e5f387a1476f4cca01752bb8",
            url:
              "https://api.github.com/repos/elixir-lang/elixir/commits/c2a9c93f023c0c00e5f387a1476f4cca01752bb8"
          },
          name: "v1.6.2",
          node_id: "MDM6UmVmMTIzNDcxNDp2MS42LjI=",
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.6.2",
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.6.2"
        },
        %Tag{
          commit: %{
            sha: "2b588dfb3ebb2f3221bec3509cb1dbb8e08ef1af",
            url:
              "https://api.github.com/repos/elixir-lang/elixir/commits/2b588dfb3ebb2f3221bec3509cb1dbb8e08ef1af"
          },
          name: "v1.6.1",
          node_id: "MDM6UmVmMTIzNDcxNDp2MS42LjE=",
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.6.1",
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.6.1"
        },
        %Tag{
          commit: %{
            sha: "63b8d0ba34f38baa6f3a11020215b2f66213d27e",
            url:
              "https://api.github.com/repos/elixir-lang/elixir/commits/63b8d0ba34f38baa6f3a11020215b2f66213d27e"
          },
          name: "v1.6.0",
          node_id: "MDM6UmVmMTIzNDcxNDp2MS42LjA=",
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.6.0",
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.6.0"
        },
        %Tag{
          commit: %{
            sha: "67e575eca7b97d4fe063626671d1fd1da0ba7fed",
            url:
              "https://api.github.com/repos/elixir-lang/elixir/commits/67e575eca7b97d4fe063626671d1fd1da0ba7fed"
          },
          name: "v1.6.0-rc.1",
          node_id: "MDM6UmVmMTIzNDcxNDp2MS42LjAtcmMuMQ==",
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.6.0-rc.1",
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.6.0-rc.1"
        },
        %Tag{
          commit: %{
            sha: "182c730bdb431fd1ff6789057e4903c33e377f43",
            url:
              "https://api.github.com/repos/elixir-lang/elixir/commits/182c730bdb431fd1ff6789057e4903c33e377f43"
          },
          name: "v1.6.0-rc.0",
          node_id: "MDM6UmVmMTIzNDcxNDp2MS42LjAtcmMuMA==",
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.6.0-rc.0",
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.6.0-rc.0"
        }
      ])

    :ok = DB.save(repo)
    pid = start_supervised!({Poller, {self(), repo, GithubFake, pool_id, 5_000}})
    Poller.poll(pid)
    assert_receive {:ok, _tags}, 1000

    tags = DB.get_tags(repo)

    assert length(tags) == 21
    %{repo: %{tags: state_tags}} = Poller.state(pid)
    assert state_tags == tags
  end

  test "handles rate limit errors", %{pool_id: pool_id} do
    repo = Repo.new("https://github.com/rate-limit/fake")

    assert capture_log(fn ->
             pid = start_supervised!({Poller, {self(), repo, GithubFake, pool_id, 5_000}})
             Poller.poll(pid)
             assert_receive {:error, :rate_limit, retry}
             assert retry > 0
           end) =~ "rate limit reached for repo: fake retrying in 50 ms"
  end

  test "re-schedule poll after rate limit errors", %{pool_id: pool_id} do
    repo = Repo.new("https://github.com/rate-limit/fake")

    assert capture_log(fn ->
             pid = start_supervised!({Poller, {self(), repo, GithubFake, pool_id, 50}})
             Poller.poll(pid)
             assert_receive {:error, :rate_limit, retry}
             assert_receive {:error, :rate_limit, ^retry}
           end) =~ "rate limit reached for repo: fake retrying in 50 ms"
  end

  test "handles errors when polling fails due to a custom error", %{pool_id: pool_id} do
    repo = Repo.new("https://github.com/404/fake")

    assert capture_log(fn ->
             pid = start_supervised!({Poller, {self(), repo, GithubFake, pool_id, 5_000}})
             Poller.poll(pid)
             assert_receive {:error, :not_found}
           end) =~ "error polling info for repo: fake reason: :not_found"
  end

  # TODO: test with channel failure e.g out_of_connections
  # TODO: test error publishing job
end
