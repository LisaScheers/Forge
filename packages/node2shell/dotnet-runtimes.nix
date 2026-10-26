{buildAspNetCore, ...}: {
  aspnetcore_8_0 = buildAspNetCore {
    version = "8.0.33";
    srcs.linux-x64 = {
      url = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/8.0.33/aspnetcore-runtime-8.0.33-linux-x64.tar.gz";
      sha512 = "08e37c6cd09edde60170f3f65531f1b688610f692f9de62125e2f7217bffa2ac130c9d6b49803266ac2d4916a91a277e095c226b83e8ea565d7de4014422aa6d";
    };
  };
  aspnetcore_10_0 = buildAspNetCore {
    version = "10.0.14";
    srcs.linux-x64 = {
      url = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/10.0.14/aspnetcore-runtime-10.0.14-linux-x64.tar.gz";
      sha512 = "dd024fd2616926a555b75cbf7a836f6dce998199f0596d9d75676dca2b9d59c8ee8673c6ac23473c0f1a4bdd59eb5cd02fe9ab097eeaf2dd8c8bd117c85e7031";
    };
  };
}
