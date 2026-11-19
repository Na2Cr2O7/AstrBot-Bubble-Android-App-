import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OpenSourceLicensesPage extends StatelessWidget {
  const OpenSourceLicensesPage({super.key});

  Future<List<String>> _loadLicenses() async {
    final results = await Future.wait([
      rootBundle.loadString('LICENSES/BSD-3-Clause.txt'),
      rootBundle.loadString('LICENSES/AGPL-3.0.txt'),
    ]);
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开源许可')),
      body: FutureBuilder<List<String>>(
        future: _loadLicenses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('读取许可证失败：${snapshot.error}'));
          }
          final bsd = snapshot.data![0];
          final agpl = snapshot.data![1];
          final textStyle = Theme.of(context).textTheme.bodySmall;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本 App', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text(
                  '许可证：BSD-3-Clause\n'
                  '根目录 LICENSE 与 LICENSES/BSD-3-Clause.txt 为完整文本。',
                ),
                const SizedBox(height: 16),
                Text(
                  'OpenQQ（独立组件）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  '许可证：GNU Affero General Public License v3.0\n'
                  '上游：https://github.com/feijx3/OpenQQ\n'
                  '版本：v0.4.0（commit 1f86aa3）\n\n'
                  'App 不把 OpenQQ 源码或二进制打包进 APK；安装时由脚本从上游获取。'
                  'App 会修改 package.json 的 allowScripts，并生成运行配置。'
                  '对应源码可从上述上游版本与本仓库 assets/openqq-install.sh 获取。\n\n'
                  '如果用户通过网络与修改后的 OpenQQ 交互，'
                  '可按上游地址获取对应源码；本仓库安装脚本也公开可用。',
                ),
                const SizedBox(height: 16),
                const Text(
                  '其他组件：AstrBot、NapCatQQ（旧版兼容，入口已隐藏）、'
                  'Code LFA 等，许可证以各上游仓库为准；'
                  '完整说明见仓库根目录 THIRD_PARTY_NOTICES.md。',
                ),
                const SizedBox(height: 16),
                Text(
                  'BSD-3-Clause 全文',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(),
                SelectableText(bsd, style: textStyle),
                const SizedBox(height: 24),
                Text(
                  'AGPL-3.0 全文',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(),
                SelectableText(agpl, style: textStyle),
              ],
            ),
          );
        },
      ),
    );
  }
}
