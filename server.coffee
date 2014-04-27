if process.argv.length isnt 3
  console.log 'Usage: coffee server.coffee <port>'
  process.exit()

express = require 'express'
multipart = require 'connect-multiparty'
fs = require 'fs'
{exec} = require 'child_process'

app = express()

app.get '/', (req, res) ->
  fs.readFile 'index.html', (err, data) ->
    return res.send err.toString() if err?
    res.writeHead 200,
      'content-type': 'text/html'
      'content-length': data.length
    res.end data

app.post '/upload', multipart(), (req, res) ->
  if 'string' isnt typeof req.body.menuname
    return res.redirect '/?err=menuname'
  if 'object' isnt typeof req.files.image
    return res.redirect '/?err=req'
  {menuname} = req.body
  if not /^[a-zA-Z ]*$/.exec(menuname)?
    return res.redirect '/?err=menuname'
  tempDir = '/tmp/' + Math.random() + Math.random() + '.grubboot'
  fs.mkdir tempDir, 0o700, (err) ->
    return res.send err.toString() if err?
    generateGRUB tempDir, req, res

app.listen parseInt process.argv[2]

generateGRUB = (dir, req, res) ->
  fail = (err) ->
    res.send err.toString()
    fs.unlink req.files.image.path

  bootPath = dir + '/boot'
  grubPath = bootPath + '/grub'
  cfgPath = grubPath + '/grub.cfg'
  imgPath = bootPath + '/k.bin'

  createImage = ->
    tempOut = '/tmp/' + Math.random() + Math.random() + '-img.iso'
    exec "grub-mkrescue -o #{tempOut} #{dir}", (err, stdout, stderr) ->
      # delete the GRUB configuration
      fs.unlink cfgPath, ->
        fs.unlink imgPath, ->
          fs.rmdir grubPath, ->
            fs.rmdir bootPath, ->
              fs.rmdir dir
      # send them the iso file and then delete it
      fs.stat tempOut, (err, stats) ->
        return res.send 'failed to stat ISO' if err?
        res.writeHead 200,
          'content-type': 'application/x-iso9660-image'
          'content-length': stats.size
          'content-disposition': 'attachment; filename=image.iso'
        stream = fs.createReadStream tempOut
        stream.on 'close', -> fs.unlink tempOut
        stream.pipe res

  # create the GRUB directory tree
  fs.mkdir bootPath, 0o700, (err) ->
    return fail err if err?
    fs.mkdir grubPath, 0o700, (err) ->
      return fail err if err?

      # create the grub.cfg file
      str = 'menuentry "' + req.body.menuname + '" {\n' +
        '\tmultiboot /boot/k.bin\n}'
      fs.writeFile cfgPath, str, {mode: 0o700}, (err) ->
        return fail err if err?
        fs.rename req.files.image.path, dir + '/boot/k.bin', (err) ->
          return fail err if err?
          createImage()

