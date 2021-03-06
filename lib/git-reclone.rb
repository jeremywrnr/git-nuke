# git-reclone gem
# jeremy warner

=begin
todo: add an option to automatically add a backup of the local copy
todo: add all remotes other than the origins, maintain connections
todo: -b / --backup, and this actually should be the default (maybe)
=end

require "colored"
require "fileutils"
require "git-reclone-version"

class GitReclone
  def initialize(test=false)
    @pdelay = 0.01 # constant for arrow speed
    @testing = test
    @verify = !test
  end

  def fire(args = [])
    opts = args.select {|a| a[0] == "-" }
    opts.each {|o| parse_opt o }
    exit 0 if (@testing || opts.first)
    parse_arg((args - opts).first)
  end

  def pexit(msg)
    puts msg
    exit 1
  end

  def parse_opt(o)
    case o
    when "--force", "-f"
      @verify = false
    when "--help", "-h"
      puts GitReclone::Help
    when "--version", "-v"
      puts GitReclone::Version
    end
  end

  def parse_arg(a)
    a.nil?? verify(remote) : verify(remote(a))
  end

  def no_repo?
    `git status 2>&1`.split("\n").first ==
      "fatal: Not a git repository (or any of the parent directories): .git"
  end

  def git_root
    %x{git rev-parse --show-toplevel}
  end

  def remotes
    %x{git remote -v}.split("\n").map { |r| r.split[1] }.uniq
  end

  def reclonebanner
    25.times { |x| slowp "\rpreparing| ".red << "~" * x << "#==>".red }
    25.times { |x| slowp "\rpreparing| ".red << " " * x << "~" * (25 - x) << "#==>".yellow }
    printf "\rREADY.".red << " " * 50 << "\n"
  end

  def slowp(x)
    sleep @pdelay
    printf x
  end

  # trying to parse out which remote should be the new source
  def remote(search = /.*/)
    pexit "Not currently in a git repository.".yellow if no_repo?

    r = remotes.find { |gr| gr.match search }

    pexit "No remotes found in this repository.".yellow if remotes.nil?

    if r.nil?
      errmsg = "No remotes found that match #{search.to_s.red}. All remotes:\n" + remotes.join("\n")
      pexit errmsg
      return errmsg
    else
      return r
    end
  end

  # show remote to user and confirm location (unless using -f)
  def verify(r)
    reclonebanner
    puts "Remote source:\t".red << r
    puts "Local target:\t".red << git_root

    if @verify
      puts "Warning: this will completely overwrite the local copy.".yellow
      printf "Continue recloning local repo? [yN] ".yellow
      unless $stdin.gets.chomp.downcase[0] == "y"
        puts "Reclone aborted.".green
        return
      end
    end

    reclone remote, git_root.chomp unless @testing
  end

  # overwrite the local copy of the repository with the remote one
  def reclone(remote, root)
    # remove the git repo from this computer
    if !@testing
      tree = Dir.glob("*", File::FNM_DOTMATCH).select {|d| not ['.','..'].include? d }
      FileUtils.rmtree (tree)
    end

    cloner = "git clone \"#{remote}\" \"#{root}\""

    puts "Recloned successfully.".green if system(cloner)
  end
end

GitReclone::Help = <<-HELP
#{'git reclone'.red}: a git repo restoring tool

reclones from the remote listed first, overwriting your local copy.
to restore from a particular remote repository, specify the host:

    git reclone bitbucket # reclone using bitbucket
    git reclone github # reclone using github
HELP
