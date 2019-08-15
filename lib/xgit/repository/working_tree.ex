defmodule Xgit.Repository.WorkingTree do
  @moduledoc ~S"""
  A working tree is an on-disk manifestation of a commit or pending commit in
  a git repository.

  An `Xgit.Repository` may have a default working tree associated with it or
  it may not. (Such a repository is often referred to as a "bare" repository.)

  More than one working tree may be associated with a repository, though this
  is not (currently) well-tested in Xgit.

  A working tree is itself strictly tied to a file system, but it need not be
  tied to an on-disk repository instance.

  _IMPORTANT NOTE:_ This is intended as a reference implementation largely
  for testing purposes and may not necessarily handle all of the edge cases that
  the traditional `git` command-line interface will handle.
  """
  use GenServer

  alias Xgit.Repository

  require Logger

  @typedoc ~S"""
  The process ID for a `WorkingTree` process.
  """
  @type t :: pid

  @doc """
  Starts a `WorkingTree` process linked to the current process.

  ## Parameters

  `repository` is the associated `Xgit.Repository` process.

  `work_dir` is the root path for the working tree.

  `options` are passed to `GenServer.start_link/3`.

  ## Return Value

  See `GenServer.start_link/3`.

  If the process is unable to create the working directory root, the response
  will be `{:error, {:mkdir, :eexist}}` (or perhaps a different posix error code).
  """
  @spec start_link(repository :: Repository.t(), work_dir :: Path.t(), GenServer.options()) ::
          GenServer.on_start()
  def start_link(repository, work_dir, options \\ [])
      when is_pid(repository) and is_binary(work_dir) and is_list(options) do
    if Repository.valid?(repository),
      do: GenServer.start_link(__MODULE__, {repository, work_dir}, options),
      else: {:error, :invalid_repository}
  end

  @impl true
  def init({repository, work_dir}) do
    case File.mkdir_p(work_dir) do
      :ok ->
        Process.monitor(repository)
        # Read index file here or maybe in a :continue handler?
        {:ok, %{repository: repository, work_dir: work_dir}}

      {:error, reason} ->
        {:stop, {:mkdir, reason}}
    end
  end

  @doc ~S"""
  Returns `true` if the argument is a PID representing a valid `WorkingTree` process.
  """
  @spec valid?(working_tree :: term) :: boolean
  def valid?(working_tree) when is_pid(working_tree) do
    Process.alive?(working_tree) &&
      GenServer.call(working_tree, :valid_working_tree?) == :valid_working_tree
  end

  def valid?(_), do: false

  @impl true
  def handle_call(:valid_working_tree?, _from, state), do: {:reply, :valid_working_tree, state}

  def handle_call(message, _from, state) do
    Logger.warn("WorkingTree received unrecognized call #{inspect(message)}")
    {:reply, {:error, :unknown_message}, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _object, reason}, state), do: {:stop, reason, state}
end
