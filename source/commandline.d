﻿/**
 * 
 * /home/tomas/workspace/github-cli/source/github/commandline.d
 * 
 * Author:
 * Tomáš Chaloupka <chalucha@gmail.com>
 * 
 * Copyright (c) 2015 ${CopyrightHolder}
 * 
 * Boost Software License 1.0 (BSL-1.0)
 * 
 * Permission is hereby granted, free of charge, to any person or organization obtaining a copy
 * of the software and accompanying documentation covered by this license (the "Software") to use,
 * reproduce, display, distribute, execute, and transmit the Software, and to prepare derivative
 * works of the Software, and to permit third-parties to whom the Software is furnished to do so,
 * all subject to the following:
 * 
 * The copyright notices in the Software and this entire statement, including the above license
 * grant, this restriction and the following disclaimer, must be included in all copies of the Software,
 * in whole or in part, and all derivative works of the Software, unless such copies or derivative works
 * are solely in the form of machine-executable object code generated by a source language processor.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
 * PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR ANYONE
 * DISTRIBUTING THE SOFTWARE BE LIABLE FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */
module commandline;

import std.algorithm;
import std.array;
import std.datetime;
import std.exception;
import std.format;
import std.getopt;
import std.stdio;
import std.string;
import std.variant;

import stdx.data.json;

CommandGroup[] getCommands()
{
	return [
		CommandGroup("repository",
			new RepositoryStarsCommand(),
			new RepositoryForksCommand(),
			new RepositoryCollaboratorsCommand(),
			new RepositoryWatchersCommand(),
			new RepositoryReleasesCommand(),
			new RepositoryTagsCommand()
			)
	];
}

int runCommandLine(string[] args)
{
	bool extractCmd(out string cmd)
	{
		if (args.length >= 1 && !args[0].startsWith('-'))
		{
			cmd = args[0];
			args = args[1..$];
		}
		else return false;

		return true;
	}

	// strip the application name
	args = args[1 .. $];

	// parse general options
	CommonOptions options;
	auto common_args = new CommandArgs(args);
	try
	{
		options.prepare(common_args);
	}
	catch (Exception e)
	{
		writefln("Error processing arguments: %s", e.msg);
		return 1;
	}

	args = common_args.extractRemainingArgs();

	//extract the command group and command
	string cmdGrpName;
	if (!extractCmd(cmdGrpName))
	{
		writeln("No command group specified\n");
		return showHelp();
	}

	string cmdName;
	if (!extractCmd(cmdName))
	{
		writeln("No command specified\n");
		return showHelp();
	}

	auto commands = getCommands();

	// find the selected command
	Command cmd;
	foreach (grp; commands)
	{
		if (grp.name == cmdGrpName)
		{
			foreach (c; grp.commands)
			{
				if (c.name == cmdName)
				{
					cmd = c;
					break;
				}
			}
		}
	}
	
	if (!cmd)
	{
		writefln("Unknown command: %s %s", cmdGrpName, cmdName);
		writeln();
		return showHelp();
	}

	auto command_args = new CommandArgs(args);
	
	// process command line options for the selected command
	try
	{
		cmd.prepare(command_args);
	}
	catch (Throwable e)
	{
		writefln("Error processing arguments: %s", e.msg);
		return 1;
	}

	auto remaining_args = command_args.extractRemainingArgs();

	// execute the command
	int rc;
	try
	{
		rc = cmd.execute(options, remaining_args);
	}
	catch (Exception e)
	{
		writefln("Error executing command %s %s: %s", cmdGrpName, cmd.name, e.msg);
		return 1;
	}

	return 0;
}

int showHelp()
{
	//TODO: Print help
	return 1;
}

struct CommonOptions {
	bool help;
	string user;
	string password;
	OutputFormat format;

	void prepare(CommandArgs args)
	{
		args.getopt("h|help", &help, ["Display general or command specific help"]);
		args.getopt("u|user", &user, ["GitHub username"]);
		args.getopt("p|password", &password, ["GitHub user password"]);
		args.getopt("f|format", &format, ["Desired output format - one of: text, csv, raw"]);
	}
}

class CommandArgs
{
	struct Arg
	{
		Variant defaultValue;
		Variant value;
		string names;
		string[] helpText;
	}
	private
	{
		string[] m_args;
		Arg[] m_recognizedArgs;
	}

	this(string[] args)
	{
		m_args = "dummy" ~ args;
	}

	@property const(Arg)[] recognizedArgs() { return m_recognizedArgs; }

	void getopt(T)(string names, T* var, string[] help_text = null)
	{
		foreach (ref arg; m_recognizedArgs)
		{
			if (names == arg.names)
			{
				assert(help_text is null);
				*var = arg.value.get!T;
				return;
			}
		}

		assert(help_text.length > 0);
		Arg arg;
		arg.defaultValue = *var;
		arg.names = names;
		arg.helpText = help_text;
		m_args.getopt(config.passThrough, names, var);
		arg.value = *var;
		m_recognizedArgs ~= arg;
	}

	void dropAllArgs()
	{
		m_args = null;
	}

	string[] extractRemainingArgs()
	{
		auto ret = m_args[1 .. $];
		m_args = null;
		return ret;
	}
}

struct CommandGroup
{
	string name;
	Command[] commands;

	this(string name, Command[] commands...)
	{
		this.name = name;
		this.commands = commands.dup;
	}
}

/// Defines requested count type
enum Count {none, all, day, month, year}

/// Defines possible output formats
enum OutputFormat
{
	text, /// pretty printed text (default)
	csv, /// csv format with tab as a delimiter
	raw /// raw output from GitHub API (JSON)
}

/// Base class for all commands
class Command
{
	string name;
	string argumentsPattern;
	string description;
	string[] helpText;
	
	abstract void prepare(scope CommandArgs args);
	abstract int execute(CommonOptions options, string[] args);
}

/// Base class for commands which can count statistics
class CountCommand : Command
{
	override void prepare(scope CommandArgs args)
	{
		args.getopt("count", &m_count, [
				"Prints statistics for defined period."
			]);
		args.getopt("s", &m_addCount, [
				"Sum statistics to show trend. This means that count won't be zeroed on interval change but continuously added to.",
				"Usable only when count parameter is set too."
			]);
	}

	override int execute(CommonOptions options, string[] args)
	{
		enforce(m_count == Count.none || options.format != OutputFormat.raw, 
			"Invalid output format. Only text or csv are allowed for statistics output");

		return 0;
	}

protected:
	Count m_count;
	bool m_addCount;

	final void writeCount(SysTime date, int count, Count countType, OutputFormat of)
	{
		string dateStr;
		switch (countType)
		{
			case Count.day:
				dateStr = format("%d/%02d/%02d", date.year, date.month, date.day);
				break;
			case Count.month:
				dateStr = format("%d/%02d", date.year, date.month);
				break;
			case Count.year:
				dateStr = format("%d", date.year);
				break;
			default:
				assert(0, "Invalid operation");
		}
		
		if (of == OutputFormat.csv) writefln("%s\t%d", dateStr, count);
		else writefln("%s\t%10s", dateStr, count);
	}

	final void countAll(CommonOptions options, string uri, string lookFor)
	{
		int cnt;
		processRequest(options, uri,
			(ubyte[] data)
			{
				cnt += data.count(cast(ubyte[])lookFor);
			});
		
		writeln(cnt);
	}

	final void countBy(string timeField)(CommonOptions options, string uri, string[string] header = null)
	{
		int cnt;
		SysTime prevTime;
		processRequest(options, uri,
			(ubyte[] data)
			{
				auto j = parseJSONStream(cast(string)data);
				foreach(ref entry; j.readArray)
				{
					SysTime currentTime;
					entry.readObject((key)
						{
							switch (key)
							{
								case timeField:
									currentTime = SysTime.fromISOExtString(entry.readString());
									break;
								default:
									entry.skipValue();
									break;
							}
						});

					if (prevTime != SysTime.init && 
						((m_count == Count.year && prevTime.year != currentTime.year)
							|| (m_count == Count.month && prevTime.month != currentTime.month)
							|| (m_count == Count.day && prevTime.day != currentTime.day)))
					{
						writeCount(prevTime, cnt, m_count, options.format);
						if (!m_addCount) cnt = 0;
					}
					cnt++;
					prevTime = currentTime;
				}
			},
			header);

		//write the last count
		if (cnt) writeCount(prevTime, cnt, m_count, options.format);
	}
}

/// Templated execute override for counting commands
mixin template Execute(C, T, alias reader) if (is(C : Command))
{
	override int execute(CommonOptions options, string[] args)
	{
		static if (C.stringof.startsWith("Repository"))
		{
			enforce(!args.empty, "Repository path not specified!");
			enforce(args.length == 1, "Expecting just repository path argument!");

			string repoPath = args[0];
		}

		static if (is(C : CountCommand))
		{
			super.execute(options, args);

			if (m_count == Count.all) // simplified count for all
			{
				static if (is (C == RepositoryStarsCommand))
				{
					string uri = format("https://api.github.com/repos/%s/stargazers", repoPath);
					string lookFor = `"login"`;
				}
				else static if (is (C == RepositoryForksCommand))
				{
					string uri = format("https://api.github.com/repos/%s/forks", repoPath);
					string lookFor = `"full_name"`;
				}
				else static if (is (C == RepositoryReleasesCommand))
				{
					string uri = format("https://api.github.com/repos/%s/releases", repoPath);
					string lookFor = `"tag_name"`;
				}

				super.countAll(options, uri, lookFor);
				return 0;
			}
			else if (m_count != Count.none) //count objects within defined intervals
			{
				string[string] header;
				static if (is (C == RepositoryStarsCommand))
				{
					string uri = format("https://api.github.com/repos/%s/stargazers", repoPath);
					enum string timeField = "starred_at";
					header = ["Accept":"application/vnd.github.v3.star+json"];
				}
				else static if (is (C == RepositoryForksCommand))
				{
					string uri = format("https://api.github.com/repos/%s/forks?sort=oldest", repoPath);
					enum string timeField = "created_at";
				}
				else static if (is (C == RepositoryReleasesCommand))
				{
					string uri = format("https://api.github.com/repos/%s/releases", repoPath);
					enum string timeField = "created_at";
				}

				super.countBy!(timeField)(options, uri, header);
				return 0;
			}
		}

		// print some info about counted objects
		string[string] header;
		static if (is (C == RepositoryStarsCommand))
		{
			string uri = format("https://api.github.com/repos/%s/stargazers", repoPath);
			header = ["Accept":"application/vnd.github.v3.star+json"];
		}
		else static if (is (C == RepositoryForksCommand))
		{
			string uri = format("https://api.github.com/repos/%s/forks", repoPath);
		}
		else static if (is (C == RepositoryCollaboratorsCommand))
		{
			string uri = format("https://api.github.com/repos/%s/collaborators", repoPath);
		}
		else static if (is (C == RepositoryWatchersCommand))
		{
			string uri = format("https://api.github.com/repos/%s/subscribers", repoPath);
		}
		else static if (is (C == RepositoryReleasesCommand))
		{
			string uri = format("https://api.github.com/repos/%s/releases", repoPath);
		}
		else static if (is (C == RepositoryTagsCommand))
		{
			string uri = format("https://api.github.com/repos/%s/tags", repoPath);
		}

		processRequest(options, uri,
			(ubyte[] data)
			{
				if (options.format != OutputFormat.raw)
				{
					auto j = parseJSONStream(cast(string)data);
					foreach(ref entry; j.readArray)
					{
						T obj;
						entry.readObject((key)
							{
								reader(key, entry, obj);
							});

						obj.write(options);
					}
				}
				else assert(0, "Not implemented"); //TODO: Implement raw output
			},
			header);

		return 0;
	}
}

final class RepositoryStarsCommand : CountCommand
{
	this()
	{
		this.name = "stars";
		this.argumentsPattern = "owner/repository";
		this.description = "Gets repository stars info.";
		this.helpText = [
			"Gets repository stars info."
		];
	}

	mixin Execute!(typeof(this), StarInfo, processStar);

private:
	struct StarInfo
	{
		SysTime starredAt;
		long id;
		string login;
		string type;

		void write(CommonOptions opts)
		{
			if (opts.format == OutputFormat.csv)
				writefln("%d\t%s\t%s\t%s", id, login, type, starredAt.toISOExtString());
			else if (opts.format == OutputFormat.text)
				writefln("%10d\t%-40s\t%s\t%s", id, login, type, starredAt.toISOExtString());
			else assert(0, "invalid output format");
		}
	}

	void processStar(E)(string key, ref E entry, ref StarInfo star)
	{
		switch (key)
		{
			case "starred_at":
				star.starredAt = SysTime.fromISOExtString(entry.readString());
				break;
			case "user":
				entry.readObject((key)
					{
						switch (key)
						{
							case "id":
								star.id = cast(long)entry.readDouble();
								break;
							case "login":
								star.login = entry.readString();
								break;
							case "type":
								star.type = entry.readString();
								break;
							default:
								entry.skipValue();
								break;
						}
					});
				break;
			default:
				entry.skipValue();
				assert(0, "Unexpected key: " ~ key);
		}
	}
}

final class RepositoryForksCommand : CountCommand
{
	this()
	{
		this.name = "forks";
		this.argumentsPattern = "owner/repository";
		this.description = "Gets repository forks info.";
		this.helpText = [
			"Gets repository forks info."
		];
	}

	mixin Execute!(typeof(this), ForkInfo, processFork);

private:
	struct ForkInfo
	{
		long id;
		string fullName;
		SysTime createdAt;

		void write(CommonOptions opts)
		{
			if (opts.format == OutputFormat.csv)
				writefln("%d\t%s\t%s", id, fullName, createdAt.toISOExtString());
			else if (opts.format == OutputFormat.text)
				writefln("%10d\t%-40s\t%s", id, fullName, createdAt.toISOExtString());
			else assert(0, "invalid output format");
		}
	}

	void processFork(E)(string key, ref E entry, ref ForkInfo fork)
	{
		switch (key)
		{
			case "id":
				fork.id = cast(long)entry.readDouble();
				break;
			case "full_name":
				fork.fullName = entry.readString();
				break;
			case "created_at":
				fork.createdAt = SysTime.fromISOExtString(entry.readString());
				break;
			default:
				entry.skipValue();
		}
	}
}

final class RepositoryCollaboratorsCommand : Command
{
	this()
	{
		this.name = "collaborators";
		this.argumentsPattern = "owner/repository";
		this.description = "Gets repository collaborators list.";
		this.helpText = [
			"Gets repository collaborators list."
		];
	}

	override void prepare(scope CommandArgs args)
	{

	}

	mixin Execute!(typeof(this), CollaboratorInfo, processCollaborator);

private:
	struct CollaboratorInfo
	{
		long id;
		string login;

		void write(CommonOptions opts)
		{
			if (opts.format == OutputFormat.csv)
				writefln("%d\t%s", id, login);
			else if (opts.format == OutputFormat.text)
				writefln("%10d\t%s", id, login);
			else assert(0, "invalid output format");
		}
	}

	void processCollaborator(E)(string key, ref E entry, ref CollaboratorInfo collaborator)
	{
		switch (key)
		{
			case "id":
				collaborator.id = cast(long)entry.readDouble();
				break;
			case "login":
				collaborator.login = entry.readString();
				break;
			default:
				entry.skipValue();
		}
	}
}

final class RepositoryWatchersCommand : Command
{
	this()
	{
		this.name = "watchers";
		this.argumentsPattern = "owner/repository";
		this.description = "Gets repository watchers list.";
		this.helpText = [
			"Gets repository watchers list."
		];
	}

	override void prepare(scope CommandArgs args)
	{

	}

	mixin Execute!(typeof(this), WatcherInfo, processWatcher);

private:
	struct WatcherInfo
	{
		long id;
		string login;

		void write(CommonOptions opts)
		{
			if (opts.format == OutputFormat.csv)
				writefln("%d\t%s", id, login);
			else if (opts.format == OutputFormat.text)
				writefln("%10d\t%s", id, login);
			else assert(0, "invalid output format");
		}
	}

	void processWatcher(E)(string key, ref E entry, ref WatcherInfo watcher)
	{
		switch (key)
		{
			case "id":
				watcher.id = cast(long)entry.readDouble();
				break;
			case "login":
				watcher.login = entry.readString();
				break;
			default:
				entry.skipValue();
		}
	}
}

final class RepositoryReleasesCommand : CountCommand
{
	this()
	{
		this.name = "releases";
		this.argumentsPattern = "owner/repository";
		this.description = "Gets repository releases.";
		this.helpText = [
			"Gets repository releases." ~ 
			"This returns a list of releases, which does not include regular Git tags that have not been associated with a release.",
			"To get a list of Git tags, use the repository tags command."
		];
	}

	mixin Execute!(typeof(this), ReleaseInfo, processRelease);

private:
	struct ReleaseInfo
	{
		long id;
		string name;
		string targetCommitish;
		bool draft;
		bool prerelease;
		string description;
		SysTime createdAt;

		void write(CommonOptions opts)
		{
			if (opts.format == OutputFormat.csv)
				writefln("%d\t%s\t%s\t%s\t%s\t%s\t%s",
					id, name, targetCommitish, draft, prerelease, createdAt.toISOExtString(), description);
			else if (opts.format == OutputFormat.text)
				writefln("%10d\t%-10s\t%s\t%s\t%s\t%s\t%s",
					id, name, targetCommitish, draft, prerelease, createdAt.toISOExtString(), description);
			else assert(0, "invalid output format");
		}
	}

	void processRelease(E)(string key, ref E entry, ref ReleaseInfo release)
	{
		switch (key)
		{
			case "id":
				release.id = cast(long)entry.readDouble();
				break;
			case "name":
				release.name = entry.readString();
				break;
			case "target_commitish":
				release.targetCommitish = entry.readString();
				break;
			case "draft":
				release.draft = entry.readBool();
				break;
			case "prerelease":
				release.prerelease = entry.readBool();
				break;
			case "body":
				release.description = entry.readString();
				break;
			case "created_at":
				release.createdAt = SysTime.fromISOExtString(entry.readString());
				break;
			default:
				entry.skipValue();
		}
	}
}

final class RepositoryTagsCommand : Command
{
	this()
	{
		this.name = "tags";
		this.argumentsPattern = "owner/repository";
		this.description = "Gets repository tags.";
		this.helpText = [
			"Gets repository tags."
		];
	}

	override void prepare(scope CommandArgs args)
	{

	}

	mixin Execute!(typeof(this), TagInfo, processTag);

private:
	struct TagInfo
	{
		string name;
		string sha;

		void write(CommonOptions opts)
		{
			if (opts.format == OutputFormat.csv)
				writefln("%s\t%s", name, sha);
			else if (opts.format == OutputFormat.text)
				writefln("%-30s\t%s", name, sha);
			else assert(0, "invalid output format");
		}
	}

	void processTag(E)(string key, ref E entry, ref TagInfo tag)
	{
		switch (key)
		{
			case "name":
				tag.name = entry.readString();
				break;
			case "commit":
				entry.readObject((key)
					{
						switch (key)
						{
							case "sha":
								tag.sha = entry.readString();
								break;
							default:
								entry.skipValue();
								break;
						}
					});
				break;
			default:
				entry.skipValue();
		}
	}
}

/**
 * Handle HTTP request.
 * If the response is paged, it automatically walks all pages.
 * If some request fails, it will return it's status line to handle it further on.
 * 
 * Params:
 * 		options - common options
 * 		url - URL to process
 * 		dataReceived - Delegate to process response from each whole request.
 * 		header - request headers
 */
void processRequest(CommonOptions opts, string url, void delegate(ubyte[] data) dataReceived, string[string] header = null)
{
	import std.net.curl;
	import std.algorithm : splitter;
	import std.format;
	import std.base64;

	HTTP.StatusLine statusLine;
	auto client = HTTP(url);

	//custom header params
	if (header)
	{
		foreach(pair; header.byPair) client.addRequestHeader(pair[0], pair[1]);
	}

	//set basic authentication if provided
	if (!opts.user.empty)
	{
		client.setAuthentication(opts.user, opts.password);
	}

	//v3 request
	client.addRequestHeader("Accept", "application/vnd.github.v3+json");

	auto resp = Appender!(ubyte[])();
	while (true)
	{
		resp.clear();
		string links;
		client.onReceiveHeader = (in char[] key, in char[] value)
		{
			if (key == "link") links = value.idup;
		};
		client.onReceive = (ubyte[] data)
		{
			resp.put(data);
			return data.length;
		};
		auto r = client.perform(ThrowOnError.no);

		//check status
		statusLine = client.statusLine;
		if (statusLine.code >= 400) break;

		//handle received data
		dataReceived(resp.data);

		//walk pages
		if (links.empty) break; // no pages

		auto idx = links.indexOf(',');
		if (idx > 0) links = links[0..idx];
		if (links.endsWith(`rel="next"`))
		{
			//set url for the next page
			client.url = links[1..links.indexOf('>')];
		}
		else break;
	}

	if (statusLine.code >= 400)
	{
		//Parse error message
		auto j = parseJSONStream(cast(string)resp.data);
		if (!j.skipToKey("message"))
		{
			throw new Exception(format("Http error %d %s:\n%s",
				statusLine.code, statusLine.reason, cast(string)resp.data));
		}
		else
		{
			throw new Exception(format("Http error %d %s - %s",
					statusLine.code, statusLine.reason, j.readString()));
		}
	}
}
