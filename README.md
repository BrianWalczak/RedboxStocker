<h1 align="center">Redbox Stocker - Manage inventory effortlessly.</h1>

<p align="center">A feature-rich Redbox inventory software for efficiently managing Redbox kiosk inventory, titles, and more.<br></p>

> [!TIP]
> Thanks to the Redbox Tinkering Community for making this project possible! You can join the Discord server by clicking [here](https://discord.gg/redboxtinkering).

## Features
- Easily manage Redbox kiosk inventory with a streamlined interface.
- Search and update movie titles and barcodes effortlessly.
- Generate and assign new barcodes for new movie discs.

## Usage
Before you get started, you'll need to make sure Python is installed on your system and Powershell administrator is available.

Then, simply clone this repository, open the folder, and run the `init.ps1` Powershell script to launch the GUI! It's recommended that you have [Visual Studio Code](https://code.visualstudio.com/) installed for easy usage.
```bash
./init.ps1 # start the program
```

If you'd like to integrate this project in your own system, you can skip the initialization screen by providing the configuration data manually. To do this, use the following command:
```bash
./title.ps1 -Config "your json config here..." # launch the title manager
## OR ##
./barcode.ps1 -Config "your json config here..." # launch the barcode manager
```

## Contributions
If you'd like to contribute to this project, please create a pull request [here](https://github.com/BrianWalczak/RedboxStocker/pulls). You can submit your feedback or any bugs that you find, on our <a href='https://github.com/BrianWalczak/RedboxStocker/issues'>issues page</a>. Contributions are highly appreciated and will help us keep this project up-to-date!

If you'd like to support this project and its development, you can send me a donation <a href='https://buymeacoffee.com/briann'>here</a> :)

<br>
  <p align="center">Made with ♡ by <a href="https://www.brianwalczak.com">Briann</a></p>
