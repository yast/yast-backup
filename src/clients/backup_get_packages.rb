# encoding: utf-8

#  File:
#    clients/backup_get_packages.ycp
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#    Lukas Ocilka <locilka@suse.cz>
#
#  $Id$
#
#  Client for returning available packages.
#  Client used by backup module. This should save memory.
module Yast
  class BackupGetPackagesClient < Client
    def main
      Yast.import "Pkg"
      textdomain "backup"

      Yast.import "Mode"

      # Read packages available on the installation sources and writes them to the
      # temporary file. Requires at least one installation source.
      #
      # @param [String] temporary file name
      Builtins.y2milestone(
        "Reading packages available on the installation sources..."
      )

      @filename = nil
      @args = WFM.Args
      Builtins.y2milestone("Args: %1", @args)

      if Ops.get(@args, 0) != nil &&
          Ops.is_string?(Ops.get_string(@args, 0, ""))
        @filename = Ops.get_string(@args, 0, "")
      else
        Builtins.y2error("Wrong parameter for script")
        return false
      end

      # fake return for testsuites
      if Mode.test
        Builtins.y2milestone("SKIPPING")
        return true
      end

      Pkg.TargetInitialize("/")
      Pkg.SourceRestore
      Pkg.SourceStartManager(true)

      # list of available enabled installation sources
      @sources = Pkg.SourceStartCache(true)
      Builtins.y2milestone("availables sources: %1", @sources)

      # list of installed products (last installed is first in the list)
      @installed_products = Pkg.ResolvableProperties("", :product, "")
      @installed_products = Builtins.filter(@installed_products) do |p|
        Ops.get_symbol(p, "status", :none) == :installed
      end
      Builtins.y2milestone("installed products: %1", @installed_products)

      # installation sources for installed products
      @product_sources = []

      # user defined installation sources
      @nonproduct_sources = []

      if Ops.greater_than(Builtins.size(@sources), 0)
        Builtins.foreach(@sources) do |source_id|
          source_description = Pkg.SourceProductData(source_id)
          Builtins.y2debug(
            "Source %1 description: %2",
            source_id,
            source_description
          )
          # TODO: really compare whole maps? Have they same keys?
          if source_description != nil && source_description != {} &&
              Builtins.contains(@installed_products, source_description)
            @product_sources = Builtins.add(@product_sources, source_id)
          else
            @nonproduct_sources = Builtins.add(@nonproduct_sources, source_id)
          end
        end
      else
        Builtins.y2warning("No installation source configured")
      end

      Builtins.y2debug("product sources: %1", @product_sources)
      Builtins.y2debug("non product sources: %1", @nonproduct_sources)

      # TODO: use better solution than temporal disabling of the installation sources
      #       probably Pkg::GetPackages(`installed, false) should be extened to
      #       Pkg::GetPackages(`installed, false, source_id)

      # temporaly disable non-product installation sources
      if Ops.greater_than(Builtins.size(@nonproduct_sources), 0)
        Builtins.foreach(@nonproduct_sources) do |source_id|
          res = Pkg.SourceSetEnabled(source_id, false)
          if res == false
            Builtins.y2error("Cannot disable installation source %1", source_id)
          end
        end
      end

      # get all available packages at the product installation sources
      @installation_packages = Pkg.GetPackages(:available, false)

      # reenable disabled non-product installation sources
      if Ops.greater_than(Builtins.size(@nonproduct_sources), 0)
        Builtins.foreach(@nonproduct_sources) do |source_id|
          res = Pkg.SourceSetEnabled(source_id, true)
          if res == false
            Builtins.y2error("Cannot enable installation source %1", source_id)
          end
        end
      end

      # convert package description to rpm format
      # ("pkg version release arch" -> "pkg-version-release")
      @installation_packages = Builtins.maplist(@installation_packages) do |pkginfo|
        parts = Builtins.splitstring(pkginfo, " ")
        Builtins.sformat(
          "%1-%2-%3",
          Ops.get(parts, 0, ""),
          Ops.get(parts, 1, ""),
          Ops.get(parts, 2, "")
        )
      end

      # Clear the packagemanager cache
      Pkg.SourceFinishAll
      Pkg.TargetFinish

      Builtins.y2debug(
        "All 'installed && available' packages: (%1) %2",
        Builtins.size(@installation_packages),
        @installation_packages
      )

      # write the output to the temporary file
      Builtins.y2milestone(
        "Writing list of %1 packages into the %2 file",
        Builtins.size(@installation_packages),
        @filename
      )
      SCR.Write(path(".target.ycp"), @filename, @installation_packages)

      true
    end
  end
end

Yast::BackupGetPackagesClient.new.main
