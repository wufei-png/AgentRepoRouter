实现前先做个计划，我还有几个问题要讨论：
1. 当前openclaw已经安装好了，需要定义一个agent来测试这个项目的功能对吗？我知道openclaw支持多agent，再定义一个，记忆这些功能也都是有的吧？
2. 这个plan中先支持claude code，opencode，codex三个cli，通过启动的时候配置，可多选，设置fallback逻辑即可，选一个。这次直接支持docs/plans/active/mvp.md中的所有内容以及多项目route
3. 实现完后编写测试代码，要求测试覆盖所有功能点，包含单个功能的以及端到端的功能测试。端到端的需要你创建两个测试repo（在本项目的test文件夹下），测试端到端的router功能，需要每个repo有自定义的agent（.codex,.opencode.claude文件下的，以及自定义skill）acp支持调用，这样有最好的兼容性（本身就在用cli的无缝迁移）也即docs/plans/active/mvp.md要求的内容，不过要求改为2个项目来实现router：
端到端测试包括：router到repo1的特性开发（skill用build_and_test 就是完成后如何测试 测试不过应该修复直到通过）；router到repo1的bugfix(同样用build_and_test)；router到repo2的文档问答 这三种case。因此openclaw这个agent skill需要有这两个repo的地址，作用，agent的功能和skill。openclaw分两个阶段，第一个阶段如果用户的要求的项目模糊不清，和用户确认repo。随后自动确认agent和skill（这里有可能存在不同cli的支持不同，有的cli的agent和level能支持project level的，有的不行，需要调研清楚）

如果找不到对应的repo处理，返回我没找到想要处理哪个项目，问用户。
否则；找这个repo下对应的agent，如果找不到，可以直接用cli默认的agent处理。如果是直接返回结果的模式，就直接返回处理结果，否则经过openclaw这一层后，带上调用了哪个项目的哪个agent。

不要自行退出plan模式，针对你的计划，我还有几点疑问 "### 3. Fallback 策略"这里，写明是agent cli的fallback 默认claude code > opencode > codex
我之前观察到opencode的自定义agent只能在~/.config/opencode/opencode.json 中是吗，不能在repo1/.opencode下定义？确认下这点以及影响。  生成的这些配置文件的路径在哪？config/openclaw.yaml config/agents.yaml 本项目中吗，还是 ~/.openclaw 说下你的考虑 因为openclaw的agent创建和skill得在本项目外。

router需要判断agent和skill都需要，如果agent没找到就用默认的
skill如果没找到就不提示它，可能就是不需要，否则如果skill也有符合的，就跟agent说用这个skill。 最后如果经过openclaw返回 让他说明用的repo agent
和skill三项 

增加一个扫描项目，更新repo_mappings.json的skill功能


'/home/wufei/github.com/wufei-png/ClawRouter/orchai'现在的项目实现符合'/home/wufei/github.com/wufei-png/ClawRouter/.claude/plans/implementation.md'这里的实现吗，有没做的事情或者不一样的实现吗？review代码实现，查看是否有偏离，未实现的或者代码bug


'/home/wufei/github.com/wufei-png/ClawRouter/orchai'现在的项目实现符合'/home/wufei/github.com/wufei-png/ClawRouter/.claude/plans/implementation.md'这里的实现吗，重点关注这个：我想要做的是每次调用acpx都是新的会话，不要带上上一个任务的上下文，现在是这样吗


查看当前项目中的代码实现细节，注意每个主要的字段和概念，看看是否有字段没有用到的？




不要用程序检测，将提示词写到openclaw中 告诉他优先级 他自行判断用什么agent 和skill 因为这个判断需要智能。
思路就是cd到目录下，有符合要求的自定义agent和skill，就都调用 告诉这个agent用这个skill，否则就调用自定义agent，或者只用通用agent，调度任务的时候跟他说用这个skill 否则就是默认agent，无skill
cli顺序支持配置：默认为claude code>opencode>codex
总体顺序：按照cli的顺序依次查看有没有自定义agent或者自定义skill，如claude code而言，有.claude且有对应的自定义，直接用。如果所有cli都没有自定义agent或者skill
还是按照claude code>opencode>codex的顺序依次调用默认agent，如果cli没安装，报错之类的，就继续fallback到下一个，直到如果都没有，报错返回。 