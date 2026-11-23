<?php

namespace Tests\Feature\Api\V1;

use App\Models\Concerns\HasImage;
use App\Models\MenuItem;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ImageUploadTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('images');
    }

    private function disk(): Filesystem
    {
        return Storage::disk('images');
    }

    /**
     * @return array{0: int, 1: int, 2: int} width, height, image type of a stored file
     */
    private function dimensionsOf(string $path): array
    {
        $info = getimagesizefromstring($this->disk()->get($path));

        return [$info[0], $info[1], $info[2]];
    }

    private function upload(string $url, UploadedFile $file)
    {
        return $this->post($url, ['image' => $file], ['Accept' => 'application/json']);
    }

    public function test_an_owner_uploads_a_restaurant_photo_and_gets_both_sizes_as_webp(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);

        $response = $this->upload("/api/v1/restaurants/{$restaurant->id}/image", UploadedFile::fake()->image('local.jpg', 3000, 2000))
            ->assertOk()
            ->assertJsonStructure(['data' => ['image_url', 'thumbnail_url']]);

        $path = $restaurant->fresh()->image_path;
        [$width, $height, $type] = $this->dimensionsOf($path);
        $this->assertSame(IMAGETYPE_WEBP, $type);
        $this->assertSame(1200, $width, 'the long side is scaled down to 1200');
        $this->assertSame(800, $height, 'the proportions are kept');

        [$thumbWidth, $thumbHeight, $thumbType] = $this->dimensionsOf(HasImage::thumbnailPathFor($path));
        $this->assertSame([400, 400, IMAGETYPE_WEBP], [$thumbWidth, $thumbHeight, $thumbType]);

        $this->assertStringStartsWith('http', $response->json('data.image_url'));
        $this->assertStringContainsString('_thumb.webp', $response->json('data.thumbnail_url'));
    }

    public function test_a_small_image_is_not_blown_up(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);

        $this->upload("/api/v1/restaurants/{$restaurant->id}/image", UploadedFile::fake()->image('chica.png', 600, 400))->assertOk();

        [$width, $height] = $this->dimensionsOf($restaurant->fresh()->image_path);
        $this->assertSame([600, 400], [$width, $height]);
    }

    public function test_the_original_file_name_is_never_used(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);

        $this->upload("/api/v1/restaurants/{$restaurant->id}/image", UploadedFile::fake()->image('../../secreto.jpg', 500, 500))->assertOk();

        $path = $restaurant->fresh()->image_path;
        $this->assertStringNotContainsString('secreto', $path);
        $this->assertMatchesRegularExpression('#^restaurants/[0-9a-f-]{36}\.webp$#', $path);
    }

    public function test_replacing_a_photo_removes_the_old_files(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);
        $url = "/api/v1/restaurants/{$restaurant->id}/image";

        $this->upload($url, UploadedFile::fake()->image('uno.jpg', 800, 800))->assertOk();
        $first = $restaurant->fresh()->image_path;
        $this->upload($url, UploadedFile::fake()->image('dos.jpg', 800, 800))->assertOk();
        $second = $restaurant->fresh()->image_path;

        $this->assertNotSame($first, $second);
        $this->disk()->assertMissing($first);
        $this->disk()->assertMissing(HasImage::thumbnailPathFor($first));
        $this->disk()->assertExists($second);
        $this->disk()->assertExists(HasImage::thumbnailPathFor($second));
    }

    public function test_deleting_a_photo_clears_it_and_removes_the_files(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);
        $this->upload("/api/v1/restaurants/{$restaurant->id}/image", UploadedFile::fake()->image('a.jpg', 800, 800))->assertOk();
        $path = $restaurant->fresh()->image_path;

        $this->deleteJson("/api/v1/restaurants/{$restaurant->id}/image")
            ->assertOk()
            ->assertJsonPath('data.image_url', null)
            ->assertJsonPath('data.thumbnail_url', null);

        $this->assertNull($restaurant->fresh()->image_path);
        $this->disk()->assertMissing($path);
        $this->disk()->assertMissing(HasImage::thumbnailPathFor($path));
    }

    public function test_a_menu_item_photo_is_uploaded_replaced_and_deleted_with_the_item(): void
    {
        $item = MenuItem::factory()->create();
        Sanctum::actingAs($item->restaurant->owner);

        $this->upload("/api/v1/menu-items/{$item->id}/image", UploadedFile::fake()->image('taco.jpg', 1500, 1500))
            ->assertOk()
            ->assertJsonStructure(['data' => ['image_url', 'thumbnail_url']]);
        $path = $item->fresh()->image_path;
        $this->assertStringStartsWith('menu-items/', $path);
        $this->disk()->assertExists($path);

        $this->deleteJson("/api/v1/menu-items/{$item->id}")->assertNoContent();

        $this->disk()->assertMissing($path);
        $this->disk()->assertMissing(HasImage::thumbnailPathFor($path));
    }

    public function test_other_users_cannot_change_someone_elses_photos(): void
    {
        $restaurant = Restaurant::factory()->create();
        $item = MenuItem::factory()->for($restaurant)->create();

        foreach ([User::factory()->restaurantOwner()->create(), User::factory()->create(), User::factory()->courier()->create()] as $user) {
            Sanctum::actingAs($user);

            $this->upload("/api/v1/restaurants/{$restaurant->id}/image", UploadedFile::fake()->image('a.jpg', 500, 500))->assertForbidden();
            $this->upload("/api/v1/menu-items/{$item->id}/image", UploadedFile::fake()->image('a.jpg', 500, 500))->assertForbidden();
            $this->deleteJson("/api/v1/restaurants/{$restaurant->id}/image")->assertForbidden();
        }

        $this->assertSame([], $this->disk()->allFiles());
    }

    public function test_a_pending_restaurant_can_add_photos_while_it_waits_for_review(): void
    {
        $owner = User::factory()->restaurantOwner()->pending()->create();
        $restaurant = Restaurant::factory()->for($owner, 'owner')->create();
        Sanctum::actingAs($owner);

        $this->upload("/api/v1/restaurants/{$restaurant->id}/image", UploadedFile::fake()->image('a.jpg', 500, 500))->assertOk();
    }

    public function test_a_suspended_restaurant_cannot_upload(): void
    {
        $owner = User::factory()->restaurantOwner()->suspended()->create();
        $restaurant = Restaurant::factory()->for($owner, 'owner')->create();
        Sanctum::actingAs($owner);

        $this->upload("/api/v1/restaurants/{$restaurant->id}/image", UploadedFile::fake()->image('a.jpg', 500, 500))->assertForbidden();
    }

    public function test_files_that_are_not_pictures_are_rejected(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);
        $url = "/api/v1/restaurants/{$restaurant->id}/image";

        $notAnImage = UploadedFile::fake()->createWithContent('foto.jpg', 'esto es texto, no una imagen');
        $pdf = UploadedFile::fake()->create('menu.pdf', 100, 'application/pdf');
        $svg = UploadedFile::fake()->createWithContent('logo.svg', '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500"><script>alert(1)</script></svg>');
        $php = UploadedFile::fake()->createWithContent('shell.php', '<?php system($_GET["c"]);');

        foreach ([$notAnImage, $pdf, $svg, $php] as $file) {
            $this->upload($url, $file)->assertUnprocessable()->assertJsonValidationErrors('image');
        }

        $this->assertNull($restaurant->fresh()->image_path);
        $this->assertSame([], $this->disk()->allFiles());
    }

    public function test_a_picture_with_code_appended_is_stored_clean(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);

        $canvas = imagecreatetruecolor(600, 600);
        ob_start();
        imagejpeg($canvas);
        $jpeg = (string) ob_get_clean();
        $polyglot = UploadedFile::fake()->createWithContent('truco.jpg', $jpeg.'<?php system($_GET["c"]); ?>');

        $this->upload("/api/v1/restaurants/{$restaurant->id}/image", $polyglot)->assertOk();

        foreach ($this->disk()->allFiles() as $file) {
            $this->assertStringNotContainsString('<?php', $this->disk()->get($file));
        }
    }

    public function test_a_png_keeps_its_transparency(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);

        $canvas = imagecreatetruecolor(400, 400);
        imagealphablending($canvas, false);
        imagesavealpha($canvas, true);
        imagefill($canvas, 0, 0, imagecolorallocatealpha($canvas, 255, 0, 0, 127));
        ob_start();
        imagepng($canvas);
        $png = UploadedFile::fake()->createWithContent('logo.png', (string) ob_get_clean());

        $this->upload("/api/v1/restaurants/{$restaurant->id}/image", $png)->assertOk();

        $stored = imagecreatefromstring($this->disk()->get($restaurant->fresh()->image_path));
        $alpha = (imagecolorat($stored, 5, 5) >> 24) & 0x7F;
        $this->assertGreaterThan(100, $alpha, 'the corner is still transparent');
    }

    public function test_size_and_dimension_limits_are_enforced_with_clear_messages(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);
        $url = "/api/v1/restaurants/{$restaurant->id}/image";

        $this->upload($url, UploadedFile::fake()->image('chica.jpg', 100, 100))
            ->assertUnprocessable()
            ->assertJsonPath('errors.image.0', 'La imagen debe medir al menos 200 × 200 píxeles y no más de 4096 por lado.');
        $this->upload($url, UploadedFile::fake()->image('enorme.jpg', 5000, 300))->assertUnprocessable();
        $this->upload($url, UploadedFile::fake()->image('pesada.jpg', 800, 800)->size(6000))
            ->assertUnprocessable()
            ->assertJsonPath('errors.image.0', 'La imagen pesa demasiado. El máximo es 5 MB.');
        $this->postJson($url, [])->assertUnprocessable()->assertJsonPath('errors.image.0', 'Elige una imagen.');
    }

    public function test_restaurants_and_menu_items_without_a_photo_report_null_urls(): void
    {
        $restaurant = Restaurant::factory()->create();
        MenuItem::factory()->for($restaurant)->create();

        $this->getJson("/api/v1/restaurants/{$restaurant->id}")
            ->assertOk()
            ->assertJsonPath('data.image_url', null)
            ->assertJsonPath('data.menu_items.0.thumbnail_url', null);
    }

    public function test_public_listings_include_the_photo_urls(): void
    {
        $restaurant = Restaurant::factory()->create();
        Sanctum::actingAs($restaurant->owner);
        $this->upload("/api/v1/restaurants/{$restaurant->id}/image", UploadedFile::fake()->image('a.jpg', 800, 800))->assertOk();
        $this->app['auth']->forgetGuards();

        $thumbnail = $this->getJson('/api/v1/restaurants')->assertOk()->json('data.0.thumbnail_url');

        $this->assertStringStartsWith('http', $thumbnail);
        $this->assertStringContainsString('_thumb.webp', $thumbnail);
    }
}
