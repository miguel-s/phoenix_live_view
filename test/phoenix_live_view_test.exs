defmodule Phoenix.LiveViewUnitTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView

  alias Phoenix.LiveView.{Utils, Socket}
  alias Phoenix.LiveViewTest.Endpoint

  @socket Utils.configure_socket(
            %Socket{
              endpoint: Endpoint,
              router: Phoenix.LiveViewTest.Router,
              view: Phoenix.LiveViewTest.ParamCounterLive
            },
            %{
              connect_params: %{},
              connect_info: %{},
              root_view: Phoenix.LiveViewTest.ParamCounterLive,
              __changed__: %{}
            },
            nil,
            %{},
            URI.parse("https://www.example.com")
          )

  @assigns_changes %{key: "value", map: %{foo: :bar}, __changed__: %{}}
  @assigns_nil_changes %{key: "value", map: %{foo: :bar}, __changed__: nil}

  describe "flash" do
    test "get and put" do
      assert put_flash(@socket, :hello, "world").assigns.flash == %{"hello" => "world"}
      assert put_flash(@socket, :hello, :world).assigns.flash == %{"hello" => :world}
    end

    test "clear" do
      socket = put_flash(@socket, :hello, "world")
      assert clear_flash(socket).assigns.flash == %{}
      assert clear_flash(socket, :hello).assigns.flash == %{}
      assert clear_flash(socket, "hello").assigns.flash == %{}
      assert clear_flash(socket, "other").assigns.flash == %{"hello" => "world"}
    end
  end

  describe "get_connect_params" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: self()})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        get_connect_params(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: nil})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        get_connect_params(socket)
      end
    end

    test "returns nil when disconnected" do
      socket = %{@socket | transport_pid: nil}
      assert get_connect_params(socket) == nil
    end

    test "returns params connected and mounting" do
      socket = %{@socket | transport_pid: self()}
      assert get_connect_params(socket) == %{}
    end
  end

  describe "get_connect_info" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: self()})

      assert_raise RuntimeError, ~r/attempted to read connect_info/, fn ->
        get_connect_info(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: nil})

      assert_raise RuntimeError, ~r/attempted to read connect_info/, fn ->
        get_connect_info(socket)
      end
    end

    test "returns nil when disconnected" do
      socket = %{@socket | transport_pid: nil}
      assert get_connect_info(socket) == nil
    end

    test "returns params connected and mounting" do
      socket = %{@socket | transport_pid: self()}
      assert get_connect_info(socket) == %{}
    end
  end

  describe "static_changed?" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: self()})

      assert_raise RuntimeError, ~r/attempted to read static_changed?/, fn ->
        static_changed?(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: nil})

      assert_raise RuntimeError, ~r/attempted to read static_changed?/, fn ->
        static_changed?(socket)
      end
    end

    test "returns false when disconnected" do
      socket = %{@socket | transport_pid: nil}
      assert static_changed?(socket) == false
    end

    test "returns true when connected and static do not match" do
      refute static_changed?([], %{})
      refute static_changed?(["foo/bar.css"], nil)

      assert static_changed?(["foo/bar.css"], %{})
      refute static_changed?(["foo/bar.css"], %{"foo/bar.css" => "foo/bar-123456.css"})

      refute static_changed?(
               ["domain.com/foo/bar.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar.css?vsn=d"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar-123456.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar-123456.css?vsn=d"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      assert static_changed?(
               ["//domain.com/foo/bar-654321.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      assert static_changed?(
               ["foo/bar.css", "baz/bat.js"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      assert static_changed?(
               ["foo/bar.css", "baz/bat.js"],
               %{"foo/bar.css" => "foo/bar-123456.css", "p/baz/bat.js" => "p/baz/bat-123456.js"}
             )

      refute static_changed?(
               ["foo/bar.css", "baz/bat.js"],
               %{"foo/bar.css" => "foo/bar-123456.css", "baz/bat.js" => "baz/bat-123456.js"}
             )
    end

    defp static_changed?(client, latest) do
      socket = %{@socket | transport_pid: self()}
      Process.put(:cache_static_manifest_latest, latest)
      socket = put_in(socket.private.connect_params["_track_static"], client)
      static_changed?(socket)
    end
  end

  describe "assign with socket" do
    test "tracks changes" do
      socket = assign(@socket, existing: "foo")
      assert changed?(socket, :existing)

      socket = Utils.clear_changed(socket)
      socket = assign(socket, existing: "foo")
      refute changed?(socket, :existing)
    end

    test "keeps whole maps in changes" do
      socket = assign(@socket, existing: %{foo: :bar})
      socket = Utils.clear_changed(socket)

      socket = assign(socket, existing: %{foo: :baz})
      assert socket.assigns.existing == %{foo: :baz}
      assert socket.assigns.__changed__.existing == %{foo: :bar}

      socket = assign(socket, existing: %{foo: :bat})
      assert socket.assigns.existing == %{foo: :bat}
      assert socket.assigns.__changed__.existing == %{foo: :bar}

      socket = assign(socket, %{existing: %{foo: :bam}})
      assert socket.assigns.existing == %{foo: :bam}
      assert socket.assigns.__changed__.existing == %{foo: :bar}
    end
  end

  describe "assign with assigns" do
    test "tracks changes" do
      assigns = assign(@assigns_changes, key: "value")
      assert assigns.key == "value"
      refute changed?(assigns, :key)

      assigns = assign(@assigns_changes, key: "changed")
      assert assigns.key == "changed"
      assert changed?(assigns, :key)

      assigns = assign(@assigns_nil_changes, key: "changed")
      assert assigns.key == "changed"
      assert assigns.__changed__ == nil
      assert changed?(assigns, :key)
    end

    test "keeps whole maps in changes" do
      assigns = assign(@assigns_changes, map: %{foo: :baz})
      assert assigns.map == %{foo: :baz}
      assert assigns.__changed__[:map] == %{foo: :bar}

      assigns = assign(@assigns_nil_changes, map: %{foo: :baz})
      assert assigns.map == %{foo: :baz}
      assert assigns.__changed__ == nil
    end
  end

  describe "assign_new with socket" do
    test "uses socket assigns if no parent assigns are present" do
      socket =
        @socket
        |> assign(existing: "existing")
        |> assign_new(:existing, fn -> "new-existing" end)
        |> assign_new(:notexisting, fn -> "new-notexisting" end)

      assert socket.assigns == %{
               existing: "existing",
               notexisting: "new-notexisting",
               live_action: nil,
               flash: %{},
               __changed__: %{existing: true, notexisting: true}
             }
    end

    test "uses parent assigns when present and falls back to socket assigns" do
      socket =
        put_in(@socket.private[:assign_new], {%{existing: "existing-parent"}, []})
        |> assign(existing2: "existing2")
        |> assign_new(:existing, fn -> "new-existing" end)
        |> assign_new(:existing2, fn -> "new-existing2" end)
        |> assign_new(:notexisting, fn -> "new-notexisting" end)

      assert socket.assigns == %{
               existing: "existing-parent",
               existing2: "existing2",
               notexisting: "new-notexisting",
               live_action: nil,
               flash: %{},
               __changed__: %{existing: true, notexisting: true, existing2: true}
             }
    end
  end

  describe "assign_new with assigns" do
    test "tracks changes" do
      assigns = assign_new(@assigns_changes, :key, fn -> raise "won't be invoked" end)
      assert assigns.key == "value"
      refute changed?(assigns, :key)
      refute assigns.__changed__[:key]

      assigns = assign_new(@assigns_changes, :another, fn -> "changed" end)
      assert assigns.another == "changed"
      assert changed?(assigns, :another)

      assigns = assign_new(@assigns_nil_changes, :another, fn -> "changed" end)
      assert assigns.another == "changed"
      assert changed?(assigns, :another)
      assert assigns.__changed__ == nil
    end
  end

  describe "update with socket" do
    test "tracks changes" do
      socket = @socket |> assign(key: "value") |> Utils.clear_changed()

      socket = update(socket, :key, fn "value" -> "value" end)
      assert socket.assigns.key == "value"
      refute changed?(socket, :key)

      socket = update(socket, :key, fn "value" -> "changed" end)
      assert socket.assigns.key == "changed"
      assert changed?(socket, :key)
    end
  end

  describe "update with assigns" do
    test "tracks changes" do
      assigns = update(@assigns_changes, :key, fn "value" -> "value" end)
      assert assigns.key == "value"
      refute changed?(assigns, :key)

      assigns = update(@assigns_changes, :key, fn "value" -> "changed" end)
      assert assigns.key == "changed"
      assert changed?(assigns, :key)

      assigns = update(@assigns_nil_changes, :key, fn "value" -> "changed" end)
      assert assigns.key == "changed"
      assert changed?(assigns, :key)
      assert assigns.__changed__ == nil
    end
  end

  describe "redirect/2" do
    test "requires local path on to" do
      assert_raise ArgumentError, ~r"the :to option in redirect/2 expects a path", fn ->
        redirect(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in redirect/2 expects a path", fn ->
        redirect(@socket, to: "//foo.com")
      end

      assert redirect(@socket, to: "/foo").redirected == {:redirect, %{to: "/foo"}}
    end

    test "allows external paths" do
      assert redirect(@socket, external: "http://foo.com/bar").redirected ==
               {:redirect, %{external: "http://foo.com/bar"}}
    end
  end

  describe "push_redirect/2" do
    test "requires local path on to" do
      assert_raise ArgumentError, ~r"the :to option in push_redirect/2 expects a path", fn ->
        push_redirect(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in push_redirect/2 expects a path", fn ->
        push_redirect(@socket, to: "//foo.com")
      end

      assert push_redirect(@socket, to: "/counter/123").redirected ==
               {:live, :redirect, %{kind: :push, to: "/counter/123"}}
    end
  end

  describe "push_patch/2" do
    test "requires local path on to pointing to the same LiveView" do
      assert_raise ArgumentError, ~r"the :to option in push_patch/2 expects a path", fn ->
        push_patch(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in push_patch/2 expects a path", fn ->
        push_patch(@socket, to: "//foo.com")
      end

      socket = %{@socket | view: Phoenix.LiveViewTest.ParamCounterLive}

      assert push_patch(socket, to: "/counter/123").redirected ==
               {:live, :patch, %{kind: :push, to: "/counter/123"}}
    end
  end
end
