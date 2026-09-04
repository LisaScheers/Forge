{
  users = {
    lisa = "age12pj207m3u8f5ql70rccf8pm9h4xuhcgeec94gfnum7583ys9dv2qwc38tv";
  };
  # Keep host recipients as SSH public keys: agenix decrypts them with the
  # corresponding raw SSH private keys from age.identityPaths.
  hosts = {
    atlas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAENd/dAYVGayQQOwHZqzgtMZGQOlBjLUhBAt4bvTuZP";
    nook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEHlf+pLT6XITnorOuDH0j9KtrVgZktsE5rPQzw3An8y";
    vega = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAxcMSI/fLy0nITZIQcsu3KQJhi3EFAsRpTGI/yPLox3";
  };
}
