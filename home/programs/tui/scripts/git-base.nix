pkgs: [
  (import ./get_master_branch_name.nix { inherit pkgs; })
  (import ./get_pr_base.nix { inherit pkgs; })
  (import ./get_pr_number.nix { inherit pkgs; })
]
