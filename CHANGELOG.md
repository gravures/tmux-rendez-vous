# Changelog
All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

- - -
##  Changelog for release [v1.1.0]
    
    https://github.com/gravures/tmux-rendez-vous/compare/f35c61edfba7a3f23a36ebdf46d1a8ddc72dd90e..v1.1.0
    2026-08-27
  
### Documentation

  - **update README.md - ([b57580c](https://github.com/gravures/tmux-rendez-vous/commit/b57580ce6d351d41a4720a9dc42e9b030d8700ba)) - [@gravures](https://github.com/gravures)

### Features

  - **(connect)** connect-rendez-vous handle restoration of server state records - ([a89f17b](https://github.com/gravures/tmux-rendez-vous/commit/a89f17bf203ba6cc27d484eaa7e77f5b39e5258b)) - [@gravures](https://github.com/gravures)

  - **(picker)** adds restore action to fzf picker - ([7aa0753](https://github.com/gravures/tmux-rendez-vous/commit/7aa0753ad130ece9a071b6b4a45168d7e90b9043)) - [@gravures](https://github.com/gravures)

  - **(save)** save-rendez-vous now also records the server state - ([0730541](https://github.com/gravures/tmux-rendez-vous/commit/0730541d3c7c41216b7a17c7995109fbd7a0bef7)) - [@gravures](https://github.com/gravures)


### Fixes

  - **(notif)** fix bad task monitoring - ([89f1b25](https://github.com/gravures/tmux-rendez-vous/commit/89f1b25ec268d46a88bd4cd7adfa139f0f4df90a)) - [@gravures](https://github.com/gravures)

  - **(picker)** avoid empty screen in fzf picker for open and close actions - ([f35c61e](https://github.com/gravures/tmux-rendez-vous/commit/f35c61edfba7a3f23a36ebdf46d1a8ddc72dd90e)) - [@gravures](https://github.com/gravures)



- - -

##  Changelog for release [v1.0.0]
    
    https://github.com/gravures/tmux-rendez-vous/compare/67af7773f28c42f2b2e673ba6ee9be56fa40408c..v1.0.0
    2026-08-25
  
### Documentation

  - **(notes)** adds developper notes - ([76794e3](https://github.com/gravures/tmux-rendez-vous/commit/76794e38e2f96a34300279e49b5af54a83cab45e)) - [@gravures](https://github.com/gravures)

  - **(readme)** update README.md - ([212d72f](https://github.com/gravures/tmux-rendez-vous/commit/212d72f22c29d8305b33a9d1a62fbb149dfcb91c)) - [@gravures](https://github.com/gravures)


### Features

  - **(close)** allow to delete a stored session from disk - ([61154f2](https://github.com/gravures/tmux-rendez-vous/commit/61154f25fdc4976b3d72c354dd5305ac64dc0552)) - [@gravures](https://github.com/gravures)

  - **(connect)** allow connect-rendez-vous to create a new directory for incoming session - ([3db830b](https://github.com/gravures/tmux-rendez-vous/commit/3db830b94fbf6717e00ada365f3e9dba04d9e602)) - [@gravures](https://github.com/gravures)

  - **(picker)** adds modal confirmation dialog to fzf for destructive actions - ([f59a04d](https://github.com/gravures/tmux-rendez-vous/commit/f59a04d605c5c77e94670b201812355c360fb619)) - [@gravures](https://github.com/gravures)


### Fixes

  - **(env)** add safe guard against environment corruption - ([5c420b6](https://github.com/gravures/tmux-rendez-vous/commit/5c420b6c963ced461c317fb318f8de9cbb9f40eb)) - [@gravures](https://github.com/gravures)

  - **(task)** various bug fixes in task notication system - ([8a35c0c](https://github.com/gravures/tmux-rendez-vous/commit/8a35c0ce226432950814268a45609d32db67fba4)) - [@gravures](https://github.com/gravures)



- - -

##  Changelog for release [v0.2.0]
    
    https://github.com/gravures/tmux-rendez-vous/compare/473ece3c6bb3cb46bd36d14a21709d4ff344cd8a..v0.2.0
    2026-07-13
  
### Bug Fixes

  - **(save)** options handling in internal tasks - ([4c7cd7b](https://github.com/gravures/tmux-rendez-vous/commit/4c7cd7bcc4ded39be56d287fd56f32cf05ed44a4)) - [@gravures](https://github.com/gravures)


### Documentation

  - **update README.md - ([60c48c9](https://github.com/gravures/tmux-rendez-vous/commit/60c48c934e14aeeeeec30e34abd509bec36930be)) - [@gravures](https://github.com/gravures)

### Features

  - **(hooks)** add support for user hooks in session restoration - ([596b58a](https://github.com/gravures/tmux-rendez-vous/commit/596b58aa3f4e8d925daa11fc780ec5b11d03423a)) - [@gravures](https://github.com/gravures)

  - **(linked)** add support for tmux linked windows when saving and restoring sessions - ([8d38915](https://github.com/gravures/tmux-rendez-vous/commit/8d389154afa24502c2ab2cb3c028cff55dbd7291)) - [@gravures](https://github.com/gravures)


### Refactoring

  - **(list-rdv)** add option to list-rendez-vous to output icons - ([495929d](https://github.com/gravures/tmux-rendez-vous/commit/495929da8e56dee3c10e157cb47f3464c0d07054)) - [@gravures](https://github.com/gravures)

  - **(plugin)** integrates tmux-bash-lib all over the plugin bash scripts - ([473ece3](https://github.com/gravures/tmux-rendez-vous/commit/473ece3c6bb3cb46bd36d14a21709d4ff344cd8a)) - [@gravures](https://github.com/gravures)



- - -

##  Changelog for release [v0.1.0]
    https://github.com/gravures/tmux-rendez-vous/compare/c5907730a9623af249bb9b6194e02f3671c48b87..v0.1.0
    2026-04-22
  
### Documentation

  - **(plugin)** make blueprint for README.md - ([252ca8b](https://github.com/gravures/tmux-rendez-vous/commit/252ca8b622cef338e12e29117d1dc154cf594d6f)) - [@gravures](https://github.com/gravures)
  - **(plugin)** add README.md - ([461884b](https://github.com/gravures/tmux-rendez-vous/commit/461884b8bda6cbb4626635cca58c9e89953b1c5d)) - [@gravures](https://github.com/gravures)
### Features

  - **(daemon)** add a daemon saving sessions at configurable interval - ([14d24e0](https://github.com/gravures/tmux-rendez-vous/commit/14d24e0705cfe59b7b65a8d502007baf57d3395b)) - [@gravures](https://github.com/gravures)
  - **(linker)** add a tmux-menu to link window from another session - ([3beccbb](https://github.com/gravures/tmux-rendez-vous/commit/3beccbba787b662bdf447ec0ea0cf1b978edde9b)) - [@gravures](https://github.com/gravures)
  - **(mutex)** add bash mutex mechanism for linux or osx - ([8dd5bd8](https://github.com/gravures/tmux-rendez-vous/commit/8dd5bd817757152b379b9ea9ff538c16d9e48685)) - [@gravures](https://github.com/gravures)
  - **(notify)** add a ligthweight tmux task/notification system - ([ac49a74](https://github.com/gravures/tmux-rendez-vous/commit/ac49a746d207718cb21788ac72d000983811135b)) - [@gravures](https://github.com/gravures)
  - **(picker)** add the main plugin picker component - ([b6de84f](https://github.com/gravures/tmux-rendez-vous/commit/b6de84f6216728916a28ca796c75c28d9ed04bad)) - [@gravures](https://github.com/gravures)
  - **(session)** add command to save session - ([d52a81f](https://github.com/gravures/tmux-rendez-vous/commit/d52a81fba894cc7dbba05460126e2561ef8dab04)) - [@gravures](https://github.com/gravures)
  - **(session)** add command to switch / open a session - ([88fa806](https://github.com/gravures/tmux-rendez-vous/commit/88fa8062fe34ca87fad353e7387f099c72d92adf)) - [@gravures](https://github.com/gravures)
  - **(session)** add command for closing a session - ([41c3027](https://github.com/gravures/tmux-rendez-vous/commit/41c302706fa68f3aa315295f8bee6adcff4c6728)) - [@gravures](https://github.com/gravures)
  - **(session)** add command to list rendez-vous (sessions, saves and zoxide folders) - ([56624ec](https://github.com/gravures/tmux-rendez-vous/commit/56624eca643341dfc964e692ed291aa5af317deb)) - [@gravures](https://github.com/gravures)

- - -

Changelog generated by [cocogitto](https://github.com/cocogitto/cocogitto).