defmodule RepoPoller.Domain.TagTest do
  use ExUnit.Case, async: true

  alias RepoPoller.Domain.Tag

  test "creates a new tag" do
    tag_map = %{
      "name" => "v0.1",
      "commit" => %{
        "sha" => "c5b97d5ae6c19d5c5df71a34c7fbeeda2479ccbc",
        "url" =>
          "https://api.github.com/repos/octocat/Hello-World/commits/c5b97d5ae6c19d5c5df71a34c7fbeeda2479ccbc"
      },
      "zipball_url" => "https://github.com/octocat/Hello-World/zipball/v0.1",
      "tarball_url" => "https://github.com/octocat/Hello-World/tarball/v0.1"
    }

    assert %Tag{
             name: "v0.1",
             commit: %{
               sha: "c5b97d5ae6c19d5c5df71a34c7fbeeda2479ccbc",
               url:
                 "https://api.github.com/repos/octocat/Hello-World/commits/c5b97d5ae6c19d5c5df71a34c7fbeeda2479ccbc"
             },
             zipball_url: "https://github.com/octocat/Hello-World/zipball/v0.1",
             tarball_url: "https://github.com/octocat/Hello-World/tarball/v0.1"
           } == Tag.new(tag_map)
  end

  test "has new tags" do
    # no version 1.7.*
    old = [
      %Tag{name: "v1.6.6"},
      %Tag{name: "v1.6.5"},
      %Tag{name: "v1.6.4"},
      %Tag{name: "v1.6.3"},
      %Tag{name: "v1.6.2"},
      %Tag{name: "v1.6.1"},
      %Tag{name: "v1.6.0"},
      %Tag{name: "v1.6.0-rc.1"},
      %Tag{name: "v1.6.0-rc.0"}
    ]
    # with version 1.7.*
    new = [
      %Tag{name: "v1.7.2"},
      %Tag{name: "v1.7.1"},
      %Tag{name: "v1.7.0"},
      %Tag{name: "v1.7.0-rc.1"},
      %Tag{name: "v1.7.0-rc.0"},
      %Tag{name: "v1.6.6"},
      %Tag{name: "v1.6.5"},
      %Tag{name: "v1.6.4"},
      %Tag{name: "v1.6.3"},
      %Tag{name: "v1.6.2"},
      %Tag{name: "v1.6.1"},
      %Tag{name: "v1.6.0"},
      %Tag{name: "v1.6.0-rc.1"},
      %Tag{name: "v1.6.0-rc.0"}
    ]
    assert Tag.new_tags?(old, new)
  end

  test "hasn't new tags - with tags" do
    # no version 1.7.*
    old = [
      %Tag{name: "v1.7.2"},
      %Tag{name: "v1.7.1"},
      %Tag{name: "v1.7.0"},
      %Tag{name: "v1.7.0-rc.1"},
      %Tag{name: "v1.7.0-rc.0"},
      %Tag{name: "v1.6.6"},
      %Tag{name: "v1.6.5"},
      %Tag{name: "v1.6.4"},
      %Tag{name: "v1.6.3"},
      %Tag{name: "v1.6.2"},
      %Tag{name: "v1.6.1"},
      %Tag{name: "v1.6.0"},
      %Tag{name: "v1.6.0-rc.1"},
      %Tag{name: "v1.6.0-rc.0"}
    ]
    # with version 1.7.*
    new = [
      %Tag{name: "v1.7.2"},
      %Tag{name: "v1.7.1"},
      %Tag{name: "v1.7.0"},
      %Tag{name: "v1.7.0-rc.1"},
      %Tag{name: "v1.7.0-rc.0"},
      %Tag{name: "v1.6.6"},
      %Tag{name: "v1.6.5"},
      %Tag{name: "v1.6.4"},
      %Tag{name: "v1.6.3"},
      %Tag{name: "v1.6.2"},
      %Tag{name: "v1.6.1"},
      %Tag{name: "v1.6.0"},
      %Tag{name: "v1.6.0-rc.1"},
      %Tag{name: "v1.6.0-rc.0"}
    ]
    refute Tag.new_tags?(old, new)
  end

  test "hasn't new tags - without tags" do
    # no version 1.7.*
    old = []
    # with version 1.7.*
    new = []
    refute Tag.new_tags?(old, new)
  end
end