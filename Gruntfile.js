module.exports = function(grunt) {

  grunt.initConfig({
    nodewebkit: {
      options: {
        version: '0.9.0',
        build_dir: './build',
        mac: true,
        win: true,
        linux32: true,
        linux64: true,
        mac_icns: "mac_icon.icns"
      },
      src: './dist/**/*'
    },
    imagemin: {
      dynamic: {
        files: [{
          expand: true,
          cwd: './dist/',
          dest: './dist/',
          src: ['**/*.{png,jpg,gif}']
        }]
      }
    },
    copy: {
      main: {
        files: [
        {
          expand: true, 
          cwd: 'src/',
          src: ['**'],
          dest: 'dist/'
        },
        ]
      }
    },
    coffee: {
      compile: {
        files: {
          'dist/js/script.js': 'src/js/script.coffee',
        }
      }
    },
    less: {
      compile: {
        options: {
          cleancss: true,
          report: 'min',
        },
        files: {
          "dist/css/style.css": "src/css/style.less"
        }
      }
    },
    uglify: {
      options: {
        report: 'min',
      },
      dist: {
        files: {
          'dist/js/script.js': ['dist/js/script.js'],
          'dist/js/foundation.js': ['dist/js/foundation.js'],
          'dist/js/jquery-ui.js': ['dist/js/jquery-ui.js']
        }
      }
    },
    htmlmin: {
      dist: {
        options: {
          removeComments: true,
          collapseWhitespace: true
        },
        files: {
          'dist/index.html': 'src/index.html',
        }
      }
    },
    clean: {
      before: [
        'dist/**/*'
      ],
      after: [
        'dist/**/*.coffee',
        'dist/**/*.less',
        'dist/**/*.psd',
        'dist/**/*.bak',
        'dist/themes/**/node_modules',
        'dist/**/Gruntfile.js',
        'dist/**/LICENSE',
        'dist/**/README.md',
      ],
    },
    watch: {
      files: [
        'src/**/*.coffee',
        'src/**/*.less',
      ],
      tasks: ['dev']
    },
    compress: {
      options: {
        pretty: true
      },
      osx: {
        options: {
          archive: 'build/releases/osx_unstable.zip'
        },
        files: [
          {src: ['build/releases/MovieList/mac/**']}
        ]
      },
      win: {
        options: {
          archive: 'build/releases/win_unstable.zip'
        },
        files: [
          {src: ['build/releases/MovieList/win/**']}
        ]
      },
      lin32: {
        options: {
          archive: 'build/releases/lin_32_unstable.zip'
        },
        files: [
          {src: ['build/releases/MovieList/linux32/**']}
        ]
      },
      lin64: {
        options: {
          archive: 'build/releases/lin_64_unstable.zip'
        },
        files: [
          {src: ['build/releases/MovieList/linux64/**']}
        ]
      }
    }
  });

  grunt.loadNpmTasks('grunt-node-webkit-builder');
  grunt.loadNpmTasks('grunt-contrib-imagemin');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-contrib-less');
  grunt.loadNpmTasks('grunt-contrib-clean');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-htmlmin');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-compress');

  grunt.registerTask('default', ['clean:before', 'copy', 'coffee', 'less', 'nodewebkit']);
  grunt.registerTask('dev', ['coffee', 'less']);
  grunt.registerTask('release',  ['clean:before', 'copy', 'coffee', 'less', 'uglify', 'htmlmin', 'clean:after', 'imagemin', 'nodewebkit', 'compress']);

};