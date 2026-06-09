import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';

const APP_BACKGROUND_COLOR: string = '#F1F3F5';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'MahjongLedger', 'EntryAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'MahjongLedger', 'Failed to load content. %{public}s', JSON.stringify(err));
        return;
      }
      windowStage.getMainWindow((windowErr, mainWindow) => {
        if (windowErr.code) {
          hilog.error(0x0000, 'MahjongLedger', 'Failed to get main window. %{public}s', JSON.stringify(windowErr));
          return;
        }
        try {
          mainWindow.setWindowBackgroundColor(APP_BACKGROUND_COLOR);
        } catch (error) {
          const windowError = error as Error;
          hilog.error(0x0000, 'MahjongLedger', 'Failed to set window background color. %{public}s', windowError.message);
        }
        try {
          mainWindow.setWindowContainerColor(APP_BACKGROUND_COLOR, APP_BACKGROUND_COLOR);
        } catch (error) {
          const containerError = error as Error;
          hilog.error(0x0000, 'MahjongLedger', 'Failed to set window container color. %{public}s', containerError.message);
        }
      });
      hilog.info(0x0000, 'MahjongLedger', 'Content loaded');
    });
  }
}
