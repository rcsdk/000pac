


Install 

git
base-devel
pcmanfm
kitty
alacritty
curl
jq
text editor. 
warp - https://releases.warp.dev/stable/v0.2025.01.29.08.02.stable_03/Warp-x86_64.AppImage
xf86-video-intel
mesa
ffmpeg


mkdir -p ~/.config/pcmanfm/default


vim ~/.config/pcmanfm/default/pcmanfm.conf

--------------------

# ~/.config/pcmanfm/default/pcmanfm.conf

[Run Script in Kitty]
command=kitty bash -c "/home/user/bin/ai_script.sh; exec bash"
pattern=*.sh
selection_type=File
description=Run the selected script in Kitty terminal with AI integration

[Edit Script in Kitty]
command=kitty /usr/bin/nvim %f
pattern=*.sh
selection_type=File
description=Edit the selected script in Kitty terminal using nvim

[Run Script in Alacritty]
command=alacritty -e bash -c "/home/user/bin/ai_script.sh; exec bash"
pattern=*.sh
selection_type=File
description=Run the selected script in Alacritty terminal with AI integration

[Edit Script in Alacritty]
command=alacritty -e /usr/bin/nvim %f
pattern=*.sh
selection_type=File
description=Edit the selected script in Alacritty terminal using nvim

[Run Script in Warp]
command=warp bash -c "/home/user/bin/ai_script.sh; exec bash"
pattern=*.sh
selection_type=File
description=Run the selected script in Warp terminal with AI integration

[Edit Script in Warp]
command=warp /usr/bin/nvim %f
pattern=*.sh
selection_type=File
description=Edit the selected script in Warp terminal using nvim

[Run Script in Terminal with Terminal]
command=x-terminal-emulator -e bash -c "/home/user/bin/ai_script.sh; exec bash"
pattern=*.sh
selection_type=File
description=Run the selected script in the default terminal emulator with AI integration

[Edit Script in Terminal with Terminal]
command=x-terminal-emulator -e /usr/bin/nvim %f
pattern=*.sh
selection_type=File
description=Edit the selected script in the default terminal emulator using nvim


--------------------


cat ~/.config/pcmanfm/default/pcmanfm.conf










