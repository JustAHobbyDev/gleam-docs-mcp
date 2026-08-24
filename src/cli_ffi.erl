-module(cli_ffi).
-export([run/5]).

run(Executable, Args, Cwd, TimeoutMs, MaxOutputBytes) ->
    case os:find_executable(binary_to_list(Executable)) of
        false ->
            {error, <<"Executable not found: ", Executable/binary>>};
        Path ->
            open_and_collect(Path, Args, Cwd, TimeoutMs, MaxOutputBytes)
    end.

open_and_collect(Path, Args, Cwd, TimeoutMs, MaxOutputBytes) ->
    Options = [
        binary,
        exit_status,
        use_stdio,
        stderr_to_stdout,
        eof,
        {args, [binary_to_list(Arg) || Arg <- Args]},
        {cd, binary_to_list(Cwd)}
    ],
    try open_port({spawn_executable, Path}, Options) of
        Port ->
            Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
            collect(Port, Deadline, MaxOutputBytes, 0, [], false)
    catch
        error:Reason ->
            {error, format_error(Reason)}
    end.

collect(Port, Deadline, Limit, Size, Chunks, Truncated) ->
    Remaining = erlang:max(Deadline - erlang:monotonic_time(millisecond), 0),
    receive
        {Port, {data, Data}} ->
            Available = erlang:max(Limit - Size, 0),
            Keep = erlang:min(byte_size(Data), Available),
            Chunk = binary:part(Data, 0, Keep),
            NewChunks = case Keep of
                0 -> Chunks;
                _ -> [Chunk | Chunks]
            end,
            collect(
                Port,
                Deadline,
                Limit,
                Size + Keep,
                NewChunks,
                Truncated orelse Keep < byte_size(Data)
            );
        {Port, {exit_status, Status}} ->
            Output = unicode:characters_to_binary(
                iolist_to_binary(lists:reverse(Chunks))
            ),
            {ok, {command_result, Status, Output, Truncated}};
        {Port, eof} ->
            collect(Port, Deadline, Limit, Size, Chunks, Truncated)
    after Remaining ->
        try port_close(Port) of
            true -> ok
        catch
            error:_ -> ok
        end,
        {error, <<"Command timed out">>}
    end.

format_error(Reason) ->
    unicode:characters_to_binary(io_lib:format("~tp", [Reason])).
