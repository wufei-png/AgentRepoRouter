现在我想实现这样一个项目：
初始聊天总结： chat_summary.md
计划：plan.md
理解该任务，还有一些工作要探索：
1. github 项目参考：
- https://github.com/VRSEN/agency-swarm
- https://github.com/openclaw/acpx
对应本地项目：/home/wufei/github.com/VRSEN/agency-swarm 和 /home/wufei/github.com/openclaw/acpx
看看这两个项目有没有什么可借鉴的？

2. 再分agent探索还有没有可以优化的点？
3. 以及完善具体的实现方案和可行性分析

不要开始实现，继续讨论：
1. 选用acpx：有个疑问： Session 管理：按 git root 自动路由 这是什么意思？
2. Agency Swarm MasterContext：集中管理共享状态 具体什么意思？
3. 不要用多阶段，一个阶段直接按最终方案实现。
4. openclaw提示词里设计如果找不到任务对应的 agent 反馈给用户