{
  description = "NixOS configuration of Ryan Yin";

  # flake 为了确保够纯，它不依赖系统自身的 /etc/nix/nix.conf，而是在 flake.nix 中通过 nixConfig 设置
  # 但是为了确保安全性，flake 默认仅允许直接设置少数 nixConfig 参数，其他参数都需要在执行 nix 命令时指定 `--accept-flake-config`，否则会被忽略
  # <https://nixos.org/manual/nix/stable/command-ref/conf-file.html>
  # 如果有些包国内镜像下载不到，它仍然会走国外，这时候就得靠旁路由来解决了。
  # 临时修改默认网关为旁路由:  sudo ip route add default via 192.168.5.201
  #                        sudo ip route del default via 192.168.5.201
  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      # replace official cache with a mirror located in China
      "https://mirrors.bfsu.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];

    # nix community's cache server
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
      "https://xddxdd.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8=" 
    ];
  };

  # 这是 flake.nix 的标准格式，inputs 是 flake 的依赖，outputs 是 flake 的输出
  # inputs 中的每一项都被拉取、构建后，被作为参数传递给 outputs 函数
  inputs = {
    # flake inputs 有很多种引用方式，应用最广泛的是 github 的引用方式

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";       # 使用 nixos-unstable 分支 for nix flakes
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-22.11";    # unstable branch may be broken sometimes, use stable branch when necessary
    
    # nix users repository
    # used to install some packages not in nixpkgs
    # e.g. wechat-uos/qqmusic/dingtalk
    nur.url = github:nix-community/NUR;

    home-manager.url = "github:nix-community/home-manager";
    #　follows 是　inputs 中的继承语法
    # 这里使　home-manager 的　nixpkgs 这个 inputs 与当前　flake 的　inputs.nixpkgs 保持一致，避免依赖的　nixpkgs 版本不一致导致问题
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # modern window compositor
    hyprland.url = "github:hyprwm/Hyprland";
    # community wayland nixpkgs
    nixpkgs-wayland.url = "github:nix-community/nixpkgs-wayland";
  };

  # outputs 的参数都是 inputs 中定义的依赖项，可以通过它们的名称来引用。
  # 不过 self 是个例外，这个特殊参数指向 outputs 自身（自引用），以及 flake 根目录
  # 这里的 @ 语法将函数的参数 attribute set 取了个别名，方便在内部使用
  outputs = inputs@{
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      nur,
      ...
  }: {
    nixosConfigurations = {
      msi-rtx4090 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit nixpkgs-stable;
        }; 
        modules = [
          ./hosts/msi-rtx4090

          # home-manager 作为 nixos 的一个 module
          # 这样在 nixos-rebuild switch 时，home-manager 也会被自动部署，不需要额外执行 home-manager switch 命令
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # 使用 home-manager.extraSpecialArgs 自定义传递给 ./home 的参数
            home-manager.extraSpecialArgs = inputs;
            home-manager.users.ryan = import ./home;
          }

          ({pkgs, config, ... }: {
            config = {
              # use it as an overlay
              nixpkgs.overlays = [ 
                inputs.nixpkgs-wayland.overlay
              ];
            };
          })

          # This adds a nur configuration option.
          # Use `config.nur.repos.<user>.<package-name>` in NixOS Module for packages from the NUR.
          nur.nixosModules.nur
          
        ];
      };


      nixos-test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit nixpkgs-stable;
        }; 
        modules = [
          ./hosts/nixos-test

          # home-manager 作为 nixos 的一个 module
          # 这样在 nixos-rebuild switch 时，home-manager 也会被自动部署，不需要额外执行 home-manager switch 命令
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # 使用 home-manager.extraSpecialArgs 自定义传递给 ./home 的参数
            home-manager.extraSpecialArgs = inputs;
            home-manager.users.ryan = import ./home;
          }

          ({pkgs, config, ... }: {
            config = {
              # use it as an overlay
              nixpkgs.overlays = [ 
                inputs.nixpkgs-wayland.overlay
              ];
            };
          })

          # This adds a nur configuration option.
          # Use `config.nur.repos.<user>.<package-name>` in NixOS Module for packages from the NUR.
          nur.nixosModules.nur
        ];
      };

      # 如果你在 x86_64-linux 平台上执行 nix build，那么默认会使用这个配置，或者也能通过 `.#<name>` 参数来指定非 default 的配置
      # packages.x86_64-linux.default =
    };
  };
}
