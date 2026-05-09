#if Fzf
import Foundation
import Testing
@testable import SwiftyShell

struct FzfTests {

    // MARK: - Search options

    @Test func buildsDefaultCommand() {
        let command = Fzf().command()

        #expect(command.executableName == "fzf")
        #expect(command.arguments.isEmpty)
    }

    @Test func buildsFilterCommand() {
        let command = Fzf()
            .filter("main")
            .command()

        #expect(command.executableName == "fzf")
        #expect(command.arguments == ["--filter=main"])
    }

    @Test func buildsSearchOptions() {
        let command = Fzf()
            .exact()
            .ignoreCase()
            .scheme(.path)
            .algo(.v1)
            .nth("1,2")
            .delimiter(",")
            .noSort()
            .tiebreak("length,begin")
            .command()

        #expect(
            command.arguments == [
                "--exact",
                "--ignore-case",
                "--scheme=path",
                "--algo=v1",
                "--nth=1,2",
                "--no-sort",
                "--delimiter=,",
                "--tiebreak=length,begin",
            ]
        )
    }

    @Test func buildsExtendedToggle() {
        let enabled = Fzf().extended(true).command()
        #expect(enabled.arguments == ["--extended"])

        let disabled = Fzf().extended(false).command()
        #expect(disabled.arguments == ["--no-extended"])
    }

    // MARK: - I/O options

    @Test func buildsIOOptions() {
        let command = Fzf()
            .read0()
            .print0()
            .ansi()
            .sync()
            .command()

        #expect(command.arguments == ["--read0", "--print0", "--ansi", "--sync"])
    }

    // MARK: - Display mode

    @Test func buildsDisplayMode() {
        let command = Fzf()
            .height("40%")
            .minHeight("10+")
            .popup("center,80%")
            .command()

        #expect(
            command.arguments == [
                "--height=40%",
                "--min-height=10+",
                "--popup=center,80%",
            ]
        )
    }

    @Test func buildsPopupWithoutSpec() {
        let command = Fzf().popup().command()
        #expect(command.arguments == ["--popup"])
    }

    // MARK: - Layout

    @Test func buildsLayoutOptions() {
        let command = Fzf()
            .reverse()
            .margin("5%")
            .padding("1,2")
            .border(.rounded)
            .borderLabel("Demo")
            .borderLabelPos("3:bottom")
            .command()

        #expect(
            command.arguments == [
                "--layout=reverse",
                "--margin=5%",
                "--padding=1,2",
                "--border=rounded",
                "--border-label=Demo",
                "--border-label-pos=3:bottom",
            ]
        )
    }

    @Test func buildsBorderWithoutStyle() {
        let command = Fzf().border().command()
        #expect(command.arguments == ["--border"])
    }

    // MARK: - List section

    @Test func buildsMultiOptions() {
        let unlimited = Fzf().multi().command()
        #expect(unlimited.arguments == ["--multi"])

        let limited = Fzf().multi(5).command()
        #expect(limited.arguments == ["--multi=5"])
    }

    @Test func buildsListOptions() {
        let command = Fzf()
            .highlightLine()
            .cycle()
            .tac()
            .keepRight()
            .noHscroll()
            .pointer(">")
            .marker("*")
            .command()

        #expect(
            command.arguments == [
                "--highlight-line",
                "--cycle",
                "--tac",
                "--keep-right",
                "--no-hscroll",
                "--pointer=>",
                "--marker=*",
            ]
        )
    }

    @Test func buildsScrollbar() {
        let custom = Fzf().scrollbar(":").command()
        #expect(custom.arguments == ["--scrollbar=:"])

        let hidden = Fzf().scrollbar(nil).command()
        #expect(hidden.arguments == ["--no-scrollbar"])
    }

    // MARK: - Input section

    @Test func buildsInputOptions() {
        let command = Fzf()
            .noInput()
            .prompt("search> ")
            .info(.hidden)
            .separator(nil)
            .ghost("Type to search...")
            .filepathWord()
            .command()

        #expect(
            command.arguments == [
                "--no-input",
                "--prompt=search> ",
                "--info=hidden",
                "--no-separator",
                "--ghost=Type to search...",
                "--filepath-word",
            ]
        )
    }

    @Test func buildsInfoStyles() {
        #expect(Fzf().info(.inline()).command().arguments == ["--info=inline"])
        #expect(Fzf().info(.inline(prefix: " << ")).command().arguments == ["--info=inline: << "])
        #expect(Fzf().info(.inlineRight()).command().arguments == ["--info=inline-right"])
    }

    // MARK: - Preview

    @Test func buildsPreviewOptions() {
        let command = Fzf()
            .preview("cat {}")
            .previewWindow("right,50%,border-rounded")
            .previewBorder(.sharp)
            .previewLabel("Preview")
            .previewLabelPos("-3:bottom")
            .command()

        #expect(
            command.arguments == [
                "--preview=cat {}",
                "--preview-window=right,50%,border-rounded",
                "--preview-border=sharp",
                "--preview-label=Preview",
                "--preview-label-pos=-3:bottom",
            ]
        )
    }

    // MARK: - Header / Footer

    @Test func buildsHeaderFooter() {
        let command = Fzf()
            .header("Press CTRL-R to reload")
            .headerLines(1)
            .headerFirst()
            .footer("Status line")
            .command()

        #expect(
            command.arguments == [
                "--header=Press CTRL-R to reload",
                "--header-lines=1",
                "--header-first",
                "--footer=Status line",
            ]
        )
    }

    // MARK: - Scripting

    @Test func buildsScriptingOptions() {
        let command = Fzf()
            .query("initial")
            .select1()
            .exit0()
            .printQuery()
            .expect("ctrl-v,ctrl-t")
            .noClear()
            .command()

        #expect(
            command.arguments == [
                "--query=initial",
                "--select-1",
                "--exit-0",
                "--print-query",
                "--expect=ctrl-v,ctrl-t",
                "--no-clear",
            ]
        )
    }

    // MARK: - Bindings

    @Test func buildsMultipleBindings() {
        let command = Fzf()
            .bind("enter:become(vim {})")
            .bind("ctrl-r:reload(ps -ef)")
            .command()

        #expect(
            command.arguments == [
                "--bind=enter:become(vim {})",
                "--bind=ctrl-r:reload(ps -ef)",
            ]
        )
    }

    // MARK: - Advanced

    @Test func buildsAdvancedOptions() {
        let command = Fzf()
            .withShell("bash -c")
            .listen("6266")
            .threads(4)
            .command()

        #expect(
            command.arguments == [
                "--with-shell=bash -c",
                "--listen=6266",
                "--threads=4",
            ]
        )
    }

    @Test func buildsListenWithoutAddress() {
        let command = Fzf().listen().command()
        #expect(command.arguments == ["--listen"])
    }

    // MARK: - Directory traversal

    @Test func buildsWalkerOptions() {
        let command = Fzf()
            .walker("file,dir,follow")
            .walkerRoot(["/home", "/tmp"])
            .walkerSkip(".git,node_modules")
            .command()

        #expect(
            command.arguments == [
                "--walker=file,dir,follow",
                "--walker-root=/home",
                "--walker-root=/tmp",
                "--walker-skip=.git,node_modules",
            ]
        )
    }

    // MARK: - History

    @Test func buildsHistoryOptions() {
        let command = Fzf()
            .history("/tmp/fzf-history")
            .historySize(500)
            .command()

        #expect(
            command.arguments == [
                "--history=/tmp/fzf-history",
                "--history-size=500",
            ]
        )
    }

    // MARK: - Style and color

    @Test func buildsStyleAndColor() {
        let command = Fzf()
            .style("full")
            .color("bg:237,bg+:236")
            .color("hl:65")
            .noColor(false)
            .noBold()
            .black()
            .command()

        #expect(
            command.arguments == [
                "--style=full",
                "--color=bg:237,bg+:236",
                "--color=hl:65",
                "--no-bold",
                "--black",
            ]
        )
    }

    // MARK: - Others

    @Test func buildsOtherOptions() {
        let command = Fzf()
            .noMouse()
            .noUnicode()
            .ambidouble()
            .command()

        #expect(
            command.arguments == [
                "--no-mouse",
                "--no-unicode",
                "--ambidouble",
            ]
        )
    }

    // MARK: - Integration test (filter mode)

    @Test func runsFilterMode() async throws {
        // Only run if fzf is installed
        let whichOutput = try await Command("which", arguments: "fzf").run(in: ShellContext())
        guard whichOutput.exitCode == 0 else { return }

        let output = try await Command("printf", arguments: "alpha\nbeta\ngamma\n")
            .pipe(to: Fzf().filter("bet").command())
            .run(in: ShellContext())

        #expect(output.stdout.contains("beta"))
        #expect(output.exitCode == 0)
    }

    // MARK: - Complex compound command

    @Test func buildsComprehensiveCommand() {
        let command = Fzf()
            .exact()
            .ignoreCase()
            .scheme(.history)
            .noSort()
            .read0()
            .print0()
            .height("40%")
            .reverse()
            .border(.rounded)
            .multi()
            .cycle()
            .tac()
            .prompt("history> ")
            .info(.hidden)
            .preview("echo {}")
            .previewWindow("right,50%")
            .header("Search history")
            .headerLines(1)
            .query("git")
            .select1()
            .exit0()
            .bind("ctrl-r:reload(history)")
            .noMouse()
            .command()

        #expect(command.executableName == "fzf")
        #expect(command.arguments.contains("--exact"))
        #expect(command.arguments.contains("--ignore-case"))
        #expect(command.arguments.contains("--scheme=history"))
        #expect(command.arguments.contains("--no-sort"))
        #expect(command.arguments.contains("--read0"))
        #expect(command.arguments.contains("--print0"))
        #expect(command.arguments.contains("--height=40%"))
        #expect(command.arguments.contains("--layout=reverse"))
        #expect(command.arguments.contains("--border=rounded"))
        #expect(command.arguments.contains("--multi"))
        #expect(command.arguments.contains("--cycle"))
        #expect(command.arguments.contains("--tac"))
        #expect(command.arguments.contains("--prompt=history> "))
        #expect(command.arguments.contains("--info=hidden"))
        #expect(command.arguments.contains("--preview=echo {}"))
        #expect(command.arguments.contains("--preview-window=right,50%"))
        #expect(command.arguments.contains("--header=Search history"))
        #expect(command.arguments.contains("--header-lines=1"))
        #expect(command.arguments.contains("--query=git"))
        #expect(command.arguments.contains("--select-1"))
        #expect(command.arguments.contains("--exit-0"))
        #expect(command.arguments.contains("--bind=ctrl-r:reload(history)"))
        #expect(command.arguments.contains("--no-mouse"))
    }
}
#endif
